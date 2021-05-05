use "asking"
use "collections"
use "interpolate"

trait val HelperState
  fun start(hsm: HelperStateMachine ref): HelperState =>
    ErrorState
  fun repos(hsm: HelperStateMachine ref, resp: Response): HelperState =>
    ErrorState
  fun finished_repos(hsm: HelperStateMachine ref): HelperState =>
    ErrorState
  fun repo_issues(hsm: HelperStateMachine ref, resp: Response, repo: String): HelperState =>
    ErrorState

primitive ErrorState is HelperState

primitive AwaitingRepos is HelperState
  fun start(hsm: HelperStateMachine ref): HelperState =>
    try
      let url: String =
        "https://api.github.com/orgs/" + hsm.ctx.org + "/repos"
      GetRepoNames(hsm, url)?
    end
    AwaitingRepos

  fun repos(hsm: HelperStateMachine ref, resp: Response): HelperState =>
    try
      (let repos_list, let next, let last) = ExtractReposNextLastFromResponse(resp)?

      hsm.ctx.repos.append(repos_list)

      for repo in repos_list.values() do
        hsm.ctx.issues(repo) = Array[Issue](1000)
        hsm.ctx.prs(repo) = Array[PR](1000)
      end

      match next
      | let next': String =>
        GetRepoNames(hsm, next')?
      else
        hsm.finished_repos()
      end
    end
    AwaitingRepos

  fun finished_repos(hsm: HelperStateMachine ref): HelperState =>
    Sort[Array[String], String](hsm.ctx.repos)

    for r in hsm.ctx.repos.values() do
      try
        GetRepoIssues(hsm, r)?
      end
    end

    AwaitingRepoIssues

primitive AwaitingRepoIssues is HelperState
  fun repo_issues(hsm: HelperStateMachine ref, resp: Response, repo: String): HelperState =>
    try
      (let issues, let next, let last) = ExtractIssuesNextLastFromResponse(resp)?

      for i in issues.values() do
        match i
        | let issue: Issue =>
          hsm.ctx.issues(repo)?.push(issue)
        | let pr: PR =>
          hsm.ctx.prs(repo)?.push(pr)
        end
      end

      match next
      | let next': String =>
        GetRepoIssues(hsm, repo, next')?
      else
        hsm.ctx.received_all_issues.set(repo)
      end
    end

    if hsm.ctx.received_all_issues.size() == hsm.ctx.repos.size() then
      let output = Array[String]

      let int = Interpolate("  * {} ([{}]({}))")

      for r in hsm.ctx.repos.values() do
        let prs = hsm.ctx.prs.get_or_else(r, [])
        let iss = hsm.ctx.issues.get_or_else(r, [])

        if (prs.size() == 0) and (iss.size() == 0) and (not hsm.ctx.show_empty) then
          continue
        end

        output.push("**" + r + "**")

        output.push("* prs: " + prs.size().string())

        for pr in prs.values() do
          output.push(int([pr.title; pr.number; pr.url].values()))
        end

        output.push("* issues: " + iss.size().string())

        for issue in iss.values() do
          output.push(int([issue.title; issue.number; issue.url].values()))
        end

        output.push("")
      end
      hsm.ctx.out.print("\n".join(output.values()))

    end

    AwaitingRepoIssues

primitive GetRepoNames
  fun apply(hsm: HelperStateMachine ref, url: String) ? =>
    let hsm_t: HelperStateMachine = hsm
    Asking(hsm.ctx.auth,
      url,
      CheckerWrapper({(resp: Response) => hsm_t.http_error(resp)}, {(resp: Response) => hsm_t.repos(resp)})
      where method = "GET", headers = hsm.ctx.headers)?

primitive GetRepoIssues
  fun apply(hsm: HelperStateMachine ref, repo: String, url: (None | String) = None) ? =>
    let hsm_t: HelperStateMachine = hsm

    let url' = match url
    | let u: String =>
      u
    else
      "https://api.github.com/repos/" + repo + "/issues?since=" + hsm.ctx.since
    end

    Asking(hsm.ctx.auth,
      url',
      CheckerWrapper({(resp: Response) => hsm_t.http_error(resp)}, {(resp: Response) => hsm_t.repo_issues(resp, repo)})
      where method = "GET", headers = hsm.ctx.headers)?

class Context
  let repos: Array[String] = Array[String]
  let received_all_issues: Set[String] = Set[String]
  let issues: Map[String, Array[(Issue)]] = Map[String, Array[Issue]]
  let prs: Map[String, Array[(PR)]] = Map[String, Array[PR]]
  let org: String
  let headers: Array[(String, String)] val
  let since: String
  let show_empty: Bool
  let out: OutStream
  let err: OutStream
  let auth: AmbientAuth

  new create(headers': Array[(String, String)] val,
    org': String,
    since': String,
    show_empty': Bool,
    out': OutStream,
    err': OutStream,
    auth': AmbientAuth)
  =>
    headers = headers'
    org = org'
    since = since'
    show_empty = show_empty'
    out = out'
    err = err'
    auth = auth'

actor HelperStateMachine
  var _state: HelperState
  let ctx: Context

  new create(ctx': Context iso) =>
    _state = AwaitingRepos
    ctx = consume ctx'

  be start() =>
    _state = _state.start(this)

  be repos(resp: Response) =>
    _state = _state.repos(this, resp)

  be finished_repos() =>
    _state = _state.finished_repos(this)

  be repo_issues(resp: Response, repo: String) =>
    _state = _state.repo_issues(this, resp, repo)

  be http_error(resp: Response) =>
    ctx.err.print("ERROR!")

    for (k, v) in resp.headers.pairs() do
      ctx.err.print("".join(["("; k; ", "; v; ")"].values()))
    end
    ctx.err.print(resp.body)

    _state = ErrorState

