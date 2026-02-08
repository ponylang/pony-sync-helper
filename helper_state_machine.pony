use "collections"
use github = "github_rest_api"
use req = "github_rest_api/request"
use "interpolate"
use "promises"

actor SyncHelper
  """
  Fetches all repositories for a GitHub organization, then fetches issues
  with a given label from each repository. Outputs a markdown-formatted
  summary of PRs and issues per repo.
  """
  let _creds: req.Credentials
  let _org: String
  let _label: String
  let _show_empty: Bool
  let _out: OutStream
  let _err: OutStream
  let _repos: Array[String] = Array[String]
  let _issues: Map[String, Array[github.Issue]] =
    Map[String, Array[github.Issue]]
  let _prs: Map[String, Array[github.Issue]] =
    Map[String, Array[github.Issue]]
  let _completed: Set[String] = Set[String]

  new create(creds: req.Credentials, org: String, label: String,
    show_empty: Bool, out: OutStream, err: OutStream)
  =>
    _creds = creds
    _org = org
    _label = label
    _show_empty = show_empty
    _out = out
    _err = err

  be start() =>
    let p = github.GetOrganizationRepositories(_org, _creds)
    let self: SyncHelper tag = this
    p.next[None]({(result) => self.repos_page(consume result)})

  be repos_page(
    result: (github.PaginatedList[github.Repository] | req.RequestError))
  =>
    match result
    | let pl: github.PaginatedList[github.Repository] =>
      for repo in pl.results.values() do
        let name = repo.full_name
        _repos.push(name)
        _issues(name) = Array[github.Issue]
        _prs(name) = Array[github.Issue]
      end

      match pl.next_page()
      | let p: Promise[
        (github.PaginatedList[github.Repository] | req.RequestError)] =>
        let self: SyncHelper tag = this
        p.next[None]({(r) => self.repos_page(consume r)})
      | None =>
        _fetch_issues()
      end
    | let e: req.RequestError =>
      _print_error(e)
    end

  be issues_page(repo: String,
    result: (github.PaginatedList[github.Issue] | req.RequestError))
  =>
    match result
    | let pl: github.PaginatedList[github.Issue] =>
      for issue in pl.results.values() do
        try
          match issue.pull_request
          | let _: github.IssuePullRequest =>
            _prs(repo)?.push(issue)
          | None =>
            _issues(repo)?.push(issue)
          end
        end
      end

      match pl.next_page()
      | let p: Promise[
        (github.PaginatedList[github.Issue] | req.RequestError)] =>
        let self: SyncHelper tag = this
        p.next[None]({(r) => self.issues_page(repo, consume r)})
      | None =>
        _completed.set(repo)
        if _completed.size() == _repos.size() then
          _output()
        end
      end
    | let e: req.RequestError =>
      _print_error(e)
    end

  fun ref _fetch_issues() =>
    Sort[Array[String], String](_repos)

    if _repos.size() == 0 then
      _output()
      return
    end

    for repo_name in _repos.values() do
      let parts = repo_name.split("/")
      try
        let owner = parts(0)?
        let repo = parts(1)?
        let p = github.GetRepositoryIssues(owner, repo, _creds
          where labels = _label)
        let self: SyncHelper tag = this
        p.next[None]({(r) => self.issues_page(repo_name, consume r)})
      end
    end

  fun _output() =>
    let output = Array[String]
    let int = Interpolate("  * {} ([{}]({}))")

    for r in _repos.values() do
      let prs = _prs.get_or_else(r, [])
      let iss = _issues.get_or_else(r, [])

      if (prs.size() == 0) and (iss.size() == 0) and (not _show_empty) then
        continue
      end

      output.push("**" + r + "**")

      output.push("* prs: " + prs.size().string())
      for pr in prs.values() do
        output.push(int([pr.title; pr.number; pr.html_url].values()))
      end

      output.push("* issues: " + iss.size().string())
      for issue in iss.values() do
        output.push(int([issue.title; issue.number; issue.html_url].values()))
      end

      output.push("")
    end
    _out.print("\n".join(output.values()))

  fun _print_error(e: req.RequestError) =>
    _err.print("ERROR!")
    _err.print("Status: " + e.status.string())
    _err.print(e.response_body)
    _err.print(e.message)
