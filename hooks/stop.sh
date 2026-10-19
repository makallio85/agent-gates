#!/usr/bin/env bash
# Claude Code Stop hook: an agent may not end its turn while a pull request it
# pushed to fails a gate of that PR's repo.
#
# A PR is the session's when its URL appears in the session transcript and it
# got a commit after the session started, so PRs the agent only read or
# mentioned never block it. A repo has the gates when its default branch
# carries .github/workflows/agent-gates.yml (templates/agent-gates.yml).
#
# If GitHub cannot be asked, the agent may stop: a hook that blocks on a
# network error would trap it in a loop.
set -uo pipefail

gates="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gates"
input=$(cat)
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

started=$(head -n 50 "$transcript" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | head -n1)
[ -n "$started" ] || exit 0

prs=$(grep -oE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+' "$transcript" | sed 's#github\.com/##; s#/pull/# #' | sort -u)
[ -n "$prs" ] || exit 0

missing=""
while read -r repo pr; do
    gh api "repos/$repo/contents/.github/workflows/agent-gates.yml" --silent 2>/dev/null || continue
    state=$(gh api "repos/$repo/pulls/$pr" --jq '.state' 2>/dev/null) || continue
    [ "$state" = "open" ] || continue
    newest=$(gh api "repos/$repo/pulls/$pr/commits" --paginate --jq '.[].commit.committer.date' 2>/dev/null | sort | tail -n1)
    [ -n "$newest" ] && [[ "$newest" > "$started" ]] || continue
    reason=$("$gates/screenshots/check.sh" "$pr" "$repo" 2>&1)
    if [ $? -eq 1 ]; then
        missing+="$reason"$'\n\n'
    fi
done <<<"$prs"

[ -z "$missing" ] && exit 0

jq -n --arg reason "Screenshots are part of the task, not a follow-up. Before you stop:

$missing" '{decision: "block", reason: $reason}'
