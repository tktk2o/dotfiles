#!/bin/bash
# Invariant: claude/settings.json is valid JSON and still wires rtk into
# PreToolUse.
#
# Why: CLAUDE.md's RTK section lists this exact check as its own documented
# health check ("grep 'rtk hook claude' ~/.claude/settings.json"). rtk
# compacts every Bash tool result before it reaches the model; if this hook
# is ever dropped by an edit, every Bash call quietly gets more expensive and
# nothing errors — the only symptom is token usage creeping up.

set -u

SETTINGS="claude/settings.json"
fail=0

if [ ! -f "$SETTINGS" ]; then
    echo "FAIL: $SETTINGS not found"
    exit 1
fi

if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
    echo "FAIL: $SETTINGS is not valid JSON"
    exit 1
fi
echo "OK: $SETTINGS is valid JSON"

hook_cmd=$(jq -r '
    .hooks.PreToolUse[]?
    | select(.matcher == "Bash")
    | .hooks[]?
    | select(.type == "command")
    | .command
' "$SETTINGS")

if printf '%s\n' "$hook_cmd" | grep -qF 'rtk hook claude'; then
    echo "OK: hooks.PreToolUse (matcher Bash) runs 'rtk hook claude'"
else
    echo "FAIL: hooks.PreToolUse (matcher Bash) does not run 'rtk hook claude'"
    fail=1
fi

exit "$fail"
