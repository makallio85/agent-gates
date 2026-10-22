# agent-gates

Gates a pull request must pass before it merges, written once and used by
every repo that turns them on. They exist because a rule in a CLAUDE.md is
read, agreed with and skipped; a gate is not.

Each gate is enforced in two places that do not depend on where an agent
session was started:

1. **GitHub** — a commit status on the PR, required on the repo's default
   branch, so the PR cannot merge while the gate fails.
2. **Claude Code** — a Stop hook that will not let an agent end its turn
   while a PR it pushed to in the session fails a gate, so the agent fixes it
   before reporting back.

## Gates

| Gate | Status | Passes when |
|---|---|---|
| Screenshots | `screenshots` | The PR has a comment, newer than its last commit to the files the PR changes (outside `docs/screenshots/`), that embeds `github.com/<repo>/blob/<sha>/…?raw=true` images, or has a line starting `Screens checked:` (no screen's output can change, and which screens were checked). |

Logic: `gates/screenshots/check.sh <PR> <owner/repo>`.

The template runs the gate on a push to a ready PR, on marking a PR ready, and
on a comment holding a `?raw=true` link or a `Screens checked:` line — or one
that held either before an edit or deletion. Other comments, bot comments and
pushes to drafts cannot change the result and are skipped: a skipped job is
not billed. A skipped run gets a concurrency group of its own, so it never
cancels a real gate run. A comment-triggered run uses the default branch's
copy of the file, so a change to these conditions takes effect once merged.

## Turning the gates on in a repo

1. Copy `templates/agent-gates.yml` to the repo's `.github/workflows/agent-gates.yml`
   and merge it to the default branch. The Stop hook gates a repo only once
   that file is there.
2. Add `screenshots` (GitHub Actions) to the required status checks of the
   default branch's ruleset.

## Installing on a machine

```sh
curl -fsSL https://raw.githubusercontent.com/makallio85/agent-gates/dev/install.sh | bash
```

This clones the repo to `~/.claude/agent-gates`, makes `hooks/bootstrap.sh`
the Stop hook in `~/.claude/settings.json`, and links `cw` into
`~/.local/bin`. The hook pulls `dev` at most every 10 minutes, so a change
here reaches every machine without reinstalling.

## `cw` — start Claude Code inside a repo

```sh
cw erp        # ~/konekallio-erp
cw erp 705    # ~/agents/konekallio-erp/pr-705, made from the PR's branch if needed
```

Starting inside the repo loads its CLAUDE.md and `.claude/` settings from the
first message. The gates hold either way.
