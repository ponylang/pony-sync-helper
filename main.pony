use "argonaut"
use "asking"
use "cli"
use "debug"
use "files"
use "interpolate"
use "json"
use "regex"
use "time"

actor Main
  new create(env: Env) =>
    let cs = try
      let current_time_sec = Time.now()._1
      let default_since_time_sec = current_time_sec - (7 * 24  * 60 * 60)
      let default_since = PosixDate(default_since_time_sec, 0).format("%F")?

      CommandSpec.leaf("pony_sync_helper",
        "Gather recently modified issues from repos or all repos in a project (defaults to last 7 days)",
        [
          OptionSpec.string("since", "Get issues since a given date" where short' = 's', default' = default_since)
          OptionSpec.string_seq("repo", "Target repo" where short' = 'r')
          OptionSpec.string("github_token", "GitHub personal access token" where short' = 't', default' = "")
          OptionSpec.string("org", "Target org" where short' = 'o', default' = "")
        ]
      )? .> add_help()?
    else
      env.exitcode(-1)
      return
    end

    let cmd = match CommandParser(cs).parse(env.args, env.vars)
      | let c: Command =>
        c
      | let ch: CommandHelp =>
        ch.print_help(env.out)
        return
      | let se: SyntaxError =>
        env.err.print(se.string())
        env.exitcode(1)
        return
      end

    let token = cmd.option("github_token").string()

    let since = cmd.option("since").string()

    let repos: Array[String] val =
      recover Array[String] .> concat(cmd.option("repo").string_seq().values()) end

    let org = cmd.option("org").string()

    let headers = recover val
      [
        ("Authorization", "token " + token)
      ]
    end

    try
      let auth = env.root as AmbientAuth
      if not (org.size() == 0) then
        GetRepos(auth, env.out, env.err, org, headers, since, repos)
      else
        ListReposIssues(auth, env.out, env.err, since, headers, repos)
      end
    end

primitive GetRepos
  fun apply(auth: AmbientAuth,
    out: OutStream,
    err: OutStream,
    org: String,
    headers: Array[(String, String)] val,
    since: String,
    repos: Array[String] val)
  =>
    try
      let url = "https://api.github.com/orgs/" + org + "/repos"

      Asking(auth,
        url,
        CheckerWrapper(err, ListRepos(auth, out, err, headers, since, repos))
        where method = "GET", headers = headers,
        failure =
          {(reason: FailureReason) =>
            match reason
            | AuthFailed => err.print("auth failed")
            | ConnectionClosed => err.print("connection closed")
            | ConnectFailed => err.print("could not connect to " + url)
            end
          })?
    end

primitive ListReposIssues
  fun apply(auth: AmbientAuth,
    out: OutStream,
    err: OutStream,
    since: String,
    headers: Array[(String, String)] val,
    repos: Array[String] val)
  =>
    Debug("LISTING ISSUES FOR: ")
    Debug(repos)
    Debug(" ")

    for repo in repos.values() do
      try
        let url = "https://api.github.com/repos/" + repo + "/issues?since=" + since

        Asking(auth,
          url,
          CheckerWrapper(err, ListIssues(out, err, repo))
          where method = "GET", headers = headers)?
      end
    end

class val CheckerWrapper
  let _err: OutStream
  let _next: {(Response)} val

  new val create(err: OutStream, next: {(Response)} val) =>
    _err = err
    _next = next

  fun apply(resp: Response) =>
    if resp.status != 200 then
      _err.print("ERROR!")
      for (k, v) in resp.headers.pairs() do
        _err.print("".join(["("; k; ", "; v; ")"].values()))
      end
      _err.print(resp.body)
    else
      _next(resp)
    end

class val ListRepos
  let _auth: AmbientAuth
  let _out: OutStream
  let _err: OutStream
  let _headers: Array[(String, String)] val
  let _since: String
  let _repos: Array[String] val

  new val create(auth: AmbientAuth,
    out: OutStream,
    err: OutStream,
    headers: Array[(String, String)] val,
    since: String,
    repos: Array[String] val)
  =>
    _auth = auth
    _out = out
    _err = err
    _headers = headers
    _since = since
    _repos = repos

  fun apply(resp: Response) =>
    let body: String = recover val String .> append(resp.body) end
    try
      let repos = recover iso Array[String] .> concat(_repos.values()) end

      let json = recover val JsonDoc .> parse(body)? end

      for i in Extractor(json.data).as_array()?.values() do
        let i' = Extractor(i)
        repos.push(i'("full_name")?.as_string()?)
      end

      (let next_link, let last_link) = try
        _get_next_and_last_link(resp.headers("Link")?)
      else
        (None, None)
      end

      match next_link
      | let link: String =>
        Asking(_auth,
          link,
          CheckerWrapper(_err, ListRepos(_auth, _out, _err, _headers, _since, consume repos))
          where method = "GET", headers = _headers,
          failure =
            {(reason: FailureReason) =>
              match reason
              | AuthFailed => _err.print("auth failed")
              | ConnectionClosed => _err.print("connection closed")
              | ConnectFailed => _err.print("could not connect to " + link)
              end
            })?
      else
        ListReposIssues(_auth, _out, _err, _since, _headers, consume repos)
      end
    else
      _err.print("error parsing")
    end

  fun _get_next_and_last_link(links_string: String): ((String | None), (String | None)) =>
    // Link: <https://api.github.com/organizations/12997238/repos?page=2>; rel="next", <https://api.github.com/organizations/12997238/repos?page=2>; rel="last"
    let links_parts: Array[String] = links_string.split(",")

    var next: (None | String) = None
    var last: (None | String) = None

    try
      let regex = Regex("""\<(.*)\>; rel="(.*)"""")?

      for lp in links_parts.values() do
        let matched = regex(lp)?
        let link: String = matched(0)?
        let rel: String = matched(1)?

        match rel
        | "next" => next = link
        | "last" => last = link
        end
      end
    end

    (next, last)

class val ListIssues
  let _out: OutStream
  let _err: OutStream
  let _full_name: String

  new val create(out: OutStream, err: OutStream, full_name: String) =>
    _out = out
    _err = err
    _full_name = full_name

  fun apply(resp: Response) =>
    let issues = Array[(String, I64, String)]
    let prs = Array[(String, I64, String)]
    let body: String = recover val String .> append(resp.body) end
    try
      let json = recover val JsonDoc .> parse(body)? end

      for i in Extractor(json.data).as_array()?.values() do
        let i' = Extractor(i)
        let title = i'("title")?.as_string()?
        let number = i'("number")?.as_i64()?
        let url = i'("html_url")?.as_string()?
        try
          i'("pull_request")?
          prs.push((title, number, url))
        else
          issues.push((title, number, url))
        end
      end

      let output = recover iso String end

      let int = Interpolate("  * {} ([{}]({}))\n")

      output.append("**" + _full_name + "**\n")

      output.append("* prs: " + prs.size().string() + "\n")

      for (title, number, url) in prs.values() do
        output.append(int([title; number; url].values()))
      end

      output.append("* issues: " + issues.size().string() + "\n")

      for (title, number, url) in issues.values() do
        output.append(int([title; number; url].values()))
      end

      _out.print(output + "\n")
    else
      _err.print("error parsing")
    end
