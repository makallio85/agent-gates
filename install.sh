#!/usr/bin/env bash
# Installs the gates on a machine where Claude Code runs:
#   - clones this repo to ~/.claude/agent-gates (bootstrap.sh keeps it current),
#   - makes hooks/bootstrap.sh the Stop hook in ~/.claude/settings.json,
#     replacing any earlier copy of the screenshot hook,
#   - links bin/cw into ~/.local/bin.
# Safe to run again. The previous settings are kept as settings.json.bak.
set -euo pipefail

dest="$HOME/.claude/agent-gates"
if [ -d "$dest/.git" ]; then
    git -C "$dest" pull -q --ff-only origin dev
else
    git clone -q -b dev https://github.com/makallio85/agent-gates.git "$dest"
fi

settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$settings.bak"
hook='$HOME/.claude/agent-gates/hooks/bootstrap.sh'
jq --arg hook "$hook" '
    .hooks.Stop = ([(.hooks.Stop // [])[]
        | .hooks |= map(select((.command // "") | test("pr-screenshots|agent-gates") | not))
        | select(.hooks | length > 0)]
      + [{hooks: [{type: "command", command: $hook, timeout: 120}]}])
' "$settings.bak" > "$settings"

mkdir -p "$HOME/.local/bin"
ln -sf "$dest/bin/cw" "$HOME/.local/bin/cw"
echo "Installed: Stop hook $hook, command cw."
