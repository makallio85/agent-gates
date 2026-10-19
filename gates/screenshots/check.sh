#!/usr/bin/env bash
# Screenshot gate: does a pull request carry its screenshots?
#
#   gates/screenshots/check.sh <PR number> <owner/repo>
#
# Passes when the PR has a comment, newer than its newest code commit, that
# either embeds screenshots pinned to a commit
# (`https://github.com/<repo>/blob/<40-char sha>/…?raw=true`) or has a line
# starting `Screens checked:` (no screen can change, and which were checked).
# A code commit is one that changes a file the PR itself changes, outside
# docs/screenshots/: committing the shots never makes the comment stale, and
# neither does merging the base branch in, unless the merge touches the PR's
# own files.
# raw.githubusercontent.com links never count: they 404 on private repos.
#
# Exit 0 = passes, 1 = screenshots missing (reason on stderr), 2 = GitHub
# could not be asked. Used by the reusable workflow and the Claude Code hook.
set -euo pipefail

pr="${1:?usage: check.sh <PR number> <owner/repo>}"
repo="${2:?usage: check.sh <PR number> <owner/repo>}"

commits=$(gh api "repos/$repo/pulls/$pr/commits" --paginate --jq '.[].sha') || exit 2
pr_files=$(gh api "repos/$repo/pulls/$pr/files" --paginate --jq '[.[].filename | select(startswith("docs/screenshots/") | not)]' | jq -sc 'add // []') || exit 2

# Newest first: the first commit touching code sets the time a comment must beat.
code_at=""
for sha in $(echo "$commits" | tac); do
    info=$(gh api "repos/$repo/commits/$sha" | jq -c --argjson pr_files "$pr_files" \
        '{date: .commit.committer.date, code: ([.files[].filename] - ([.files[].filename] - $pr_files) | length)}') || exit 2
    if [ "$(jq -r .code <<<"$info")" != "0" ]; then
        code_at=$(jq -r .date <<<"$info")
        break
    fi
done
[ -n "$code_at" ] || exit 0

image="github\\.com/${repo//./\\.}/blob/[0-9a-f]{40}/[^) ]*\\?raw=true"
found=$(gh api "repos/$repo/issues/$pr/comments" --paginate | jq -rs \
    --arg after "$code_at" --arg image "$image" \
    'add // [] | map(select(.created_at > $after and ((.body | test($image)) or (.body | test("(^|\\n)\\s*Screens checked:"; "i"))))) | first | .html_url // empty') || exit 2

if [ -n "$found" ]; then
    echo "$repo#$pr: screenshots posted ($found)"
    exit 0
fi

cat >&2 <<EOF
$repo#$pr has no screenshot comment newer than its last code commit ($code_at).
Post real-browser screenshots of every screen the change can alter, desktop and
phone width, inline in a PR comment, each embedded as
  ![state](https://github.com/$repo/blob/<commit sha>/<path>?raw=true)
The repo's CLAUDE.md says how to take them there. If no screen can change,
comment a line starting "Screens checked:" naming the screens checked and why
their output stays the same.
EOF
exit 1
