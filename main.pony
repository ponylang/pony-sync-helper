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
      CommandSpec.leaf("pony_sync_helper",
        "Gather recently modified issues from repos or all repos in a project (defaults to last 7 days)",
        [
          OptionSpec.string("github_token", "GitHub personal access token" where short' = 't', default' = "")
          OptionSpec.bool("show_empty", "Show repos with no issues or PRs" where short' = 'e', default' = false)
          OptionSpec.string("org", "Target org" where short' = 'o')
          OptionSpec.string("label", "Label to search on" where short' = 'l')
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

    let org = cmd.option("org").string()

    let show_empty = cmd.option("show_empty").bool()

    let label = cmd.option("label").string()

    let headers = recover val
      [
        ("Authorization", recover val "token " + token end)
      ]
    end

    let ctx: Context iso = recover Context(headers,
      org,
      label,
      show_empty,
      env.out,
      env.err,
      env.root)
    end
    let hsm = HelperStateMachine(consume ctx)
    hsm.start()

class val CheckerWrapper
  let _err: {(Response)} val
  let _next: {(Response)} val

  new val create(err: {(Response)} val, next: {(Response)} val) =>
    _err = err
    _next = next

  fun apply(resp: Response) =>
    if resp.status != 200 then
      _err(resp)
    else
      _next(resp)
    end

primitive GetNextAndLastLink
  fun apply(resp: Response): ((String | None), (String | None)) =>
    // Link: <https://api.github.com/organizations/12997238/repos?page=2>; rel="next", <https://api.github.com/organizations/12997238/repos?page=2>; rel="last"

    var next: (None | String) = None
    var last: (None | String) = None

    try
      let links_string = resp.headers("link")?

      let links_parts: Array[String] = links_string.split(",")

      let regex = Regex("<(.*)>; rel=\"(.*)\"")?

      for lp in links_parts.values() do
        let matched = regex(lp)?

        let link: String = matched(1)?
        let rel: String = matched(2)?

        match rel
        | "next" => next = link
        | "last" => last = link
        end
      end
    end

    (next, last)

primitive ExtractReposNextLastFromResponse
  fun apply(resp: Response): (Array[String] val, (None | String), (None | String)) ? =>
    let body: String = recover val String .> append(resp.body) end
    let repos = recover iso Array[String] end
    let json = recover val JsonDoc .> parse(body)? end

    for i in JsonExtractor(json.data).as_array()?.values() do
      let i' = JsonExtractor(i)
      repos.push(i'("full_name")?.as_string()?)
    end

    (let next_link, let last_link) = GetNextAndLastLink(resp)

    (consume repos, next_link, last_link)

primitive ExtractIssuesNextLastFromResponse
  fun apply(resp: Response): (Array[(Issue | PR)] val, (None | String), (None | String)) ? =>
    let issues = recover iso Array[(Issue | PR)] end

    let body: String = recover val String .> append(resp.body) end

    (let next, let last) = GetNextAndLastLink(resp)

    let json = recover val JsonDoc .> parse(body)? end

    for i in JsonExtractor(json.data).as_array()?.values() do
      let i' = JsonExtractor(i)
      let title = i'("title")?.as_string()?
      let number = i'("number")?.as_i64()?
      let url = i'("html_url")?.as_string()?
      try
        i'("pull_request")?
        issues.push(PR(title, number, url))
      else
        issues.push(Issue(title, number, url))
      end
    end

    (consume issues, next, last)

class val Issue
  let title: String
  let number: I64
  let url: String

  new val create(title': String, number': I64, url': String) =>
    title = title'
    number = number'
    url = url'

class val PR
  let title: String
  let number: I64
  let url: String

  new val create(title': String, number': I64, url': String) =>
    title = title'
    number = number'
    url = url'
