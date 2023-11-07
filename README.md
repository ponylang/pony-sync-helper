# pony-sync-helper

## Overview

This is a tool for generating a list of issues from Pony repositories. It's primary usage is to generate a list of issues to review during the Pony sync meetings, but it can generally be used to retrieve a list of issues from all of the repos belonging to an organization.

## Building

It relies on SSL, so you must pass an SSL version to use.

```bash
corral run -- ponyc -Dopenssl_0.9.0
```

## Usage

The program uses a [GitHub personal access token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) to make calls against the GitHub API. This token is passed either via a commandline option called `--github_token` or an environment variable called `PONY_SYNC_HELPER_GITHUB_TOKEN`.

To run the program you specify the GitHub org that you want to target.

```bash
export PONY_SYNC_HELPER_GITHUB_TOKEN="12345678"
./pony-sync-helper --org ponylang --label "discuss during sync"
```

```bash
./pony-sync-helper --org ponylang --label "discuss during sync" --github_token 12345678
```

By default only repos with issues are shown. To show all repos, even those without issues, use the `--show_empty` option.

```bash
./pony-sync-helper --org ponylang  --label "discuss during sync" --show_empty --github_token 12345678
```
