#!/usr/bin/env bash
# What ~/.claude/settings.json runs as the Stop hook. It brings this clone up
# to date with makallio85/agent-gates (at most every 10 minutes, giving up
# after 10 seconds) and runs hooks/stop.sh, so every session uses the gates as
# they are on dev rather than a copy taken at install time.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
stamp="$root/.git/agent-gates-pulled"
if [ -z "$(find "$stamp" -mmin -10 2>/dev/null)" ]; then
    timeout 10 git -C "$root" pull -q --ff-only origin dev >/dev/null 2>&1 && touch "$stamp"
fi
exec "$root/hooks/stop.sh"
