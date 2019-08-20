# pony-sync-helper

## Overview

This is a tool for generating a list of issues to review during the Pony sync meetings, but it can generally be used to retrieve a list of issues from a repo or from all of the repos belonging to an organization.

## Usage

The program uses a [GitHub personal access token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line) to make calls against the GitHub API. This token is passed either via a commandline option called `--token` or an environment variable called `PONY_SYNC_HELPER_GITHUB_TOKEN`
