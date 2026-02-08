use "cli"
use "net"
use req = "github_rest_api/request"

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

    let creds = req.Credentials(TCPConnectAuth(env.root),
      if token == "" then None else token end)

    let helper = SyncHelper(creds, org, label, show_empty, env.out, env.err)
    helper.start()
