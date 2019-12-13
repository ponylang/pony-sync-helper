# pony-sync-helper

## Overview

This is a tool for generating a list of issues to review during the Pony sync meetings, but it can generally be used to retrieve a list of issues from all of the repos belonging to an organization.

## Building

This project is built to `stable`. It relies on SSL, so you must pass an SSL version to use.

```bash
stable env ponyc -Dopenssl_0.9.0
```

## Usage

The program uses a [GitHub personal access token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) to make calls against the GitHub API. This token is passed either via a commandline option called `--github_token` or an environment variable called `PONY_SYNC_HELPER_GITHUB_TOKEN`.

To run the program you specify the GitHub org that you want to target, and you can optionally specify a "since" date in `YYYY-MM-DD` format. If not "since" date is specified then it searches for issues that have been updated in the last seven (7) days.

```bash
export PONY_SYNC_HELPER_GITHUB_TOKEN="12345678"
./pony-sync-helper --org ponylang
```

```bash
./pony-sync-helper --org ponylang --since 2019-06-04 --github_token 12345678
```

By default only repos with issues in the selected range are shown. To show all repos, even those without issues in the selected range, use the `--show_empty` option.

```bash
./pony-sync-helper --org ponylang --show_empty --github_token 12345678
```
