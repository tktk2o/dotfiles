#!/bin/bash
# Invariant: scan-budget.sh nudges (never denies) at the threshold and never
# counts subagent calls. Why it exists: CLAUDE.md, "Guarded operations".

set -u

HOOK="claude/hooks/scan-budget.sh"
SETTINGS="claude/settings.json"
fail=0

run_hook() {
    local state_dir="$1" budget="$2" json="$3"
    printf '%s' "$json" | XDG_STATE_HOME="$state_dir" CLAUDE_SCAN_BUDGET="$budget" bash "$HOOK"
}

tmp_a="$(mktemp -d)"
out=$(run_hook "$tmp_a" 3 '{"session_id":"sa","agent_id":"child-1","tool_name":"Bash","tool_input":{"command":"grep foo bar"}}')
if [ -z "$out" ] && [ ! -e "$tmp_a/claude/scan-budget/sa" ]; then
    echo "OK: subagent call (agent_id set) produces no output and no counter file"
else
    echo "FAIL: subagent call was counted or produced output: '$out'"
    fail=1
fi

tmp_b="$(mktemp -d)"
out=$(run_hook "$tmp_b" 3 '{"session_id":"sb","tool_name":"Read","tool_input":{"command":"grep foo bar"}}')
if [ -z "$out" ]; then
    echo "OK: non-Bash tool_name produces no output"
else
    echo "FAIL: non-Bash tool_name produced output: '$out'"
    fail=1
fi

tmp_c="$(mktemp -d)"
out=$(run_hook "$tmp_c" 3 '{"session_id":"sc","tool_name":"Bash","tool_input":{"command":"git commit -m x"}}')
if [ -z "$out" ]; then
    echo "OK: git commit is not classified as a scan command"
else
    echo "FAIL: git commit produced output: '$out'"
    fail=1
fi

tmp_d="$(mktemp -d)"
out1=$(run_hook "$tmp_d" 3 '{"session_id":"sd","tool_name":"Bash","tool_input":{"command":"grep foo bar"}}')
out2=$(run_hook "$tmp_d" 3 '{"session_id":"sd","tool_name":"Bash","tool_input":{"command":"grep foo bar"}}')
out3=$(run_hook "$tmp_d" 3 '{"session_id":"sd","tool_name":"Bash","tool_input":{"command":"grep foo bar"}}')
ctx=$(printf '%s' "$out3" | jq -e '.hookSpecificOutput.additionalContext' 2>/dev/null)
if [ -z "$out1" ] && [ -z "$out2" ] && [ -n "$ctx" ] && [ "$ctx" != "null" ]; then
    echo "OK: threshold fires exactly on the 3rd scan command with a non-empty additionalContext"
else
    echo "FAIL: threshold sequence wrong (out1='$out1' out2='$out2' ctx='$ctx')"
    fail=1
fi

tmp_e="$(mktemp -d)"
run_hook "$tmp_e" 3 '{"session_id":"se","tool_name":"Bash","tool_input":{"command":"rtk grep foo"}}' >/dev/null
count_after_rtk=$(cat "$tmp_e/claude/scan-budget/se" 2>/dev/null)
py_cmd=$(printf 'python3 - <<'"'"'EOF'"'"'\nprint(1)\nEOF')
py_json=$(jq -cn --arg cmd "$py_cmd" '{session_id:"se",tool_name:"Bash",tool_input:{command:$cmd}}')
run_hook "$tmp_e" 3 "$py_json" >/dev/null
count_after_py=$(cat "$tmp_e/claude/scan-budget/se" 2>/dev/null)
if [ "$count_after_rtk" = "1" ] && [ "$count_after_py" = "2" ]; then
    echo "OK: 'rtk grep' and a python3 heredoc both classify as scan commands"
else
    echo "FAIL: rtk/python3 classification wrong (after rtk=$count_after_rtk after python3=$count_after_py)"
    fail=1
fi

tmp_f="$(mktemp -d)"
run_hook "$tmp_f" 3 '{"session_id":"sfa","tool_name":"Bash","tool_input":{"command":"grep x y"}}' >/dev/null
run_hook "$tmp_f" 3 '{"session_id":"sfb","tool_name":"Bash","tool_input":{"command":"grep x y"}}' >/dev/null
count_a=$(cat "$tmp_f/claude/scan-budget/sfa" 2>/dev/null)
count_b=$(cat "$tmp_f/claude/scan-budget/sfb" 2>/dev/null)
if [ "$count_a" = "1" ] && [ "$count_b" = "1" ]; then
    echo "OK: two different session_ids keep independent counters"
else
    echo "FAIL: session counters are not independent (sfa=$count_a sfb=$count_b)"
    fail=1
fi

if jq -e '.hooks.PreToolUse[]?.hooks[]?.command // empty' "$SETTINGS" 2>/dev/null | grep -q 'scan-budget.sh'; then
    echo "OK: $SETTINGS wires scan-budget.sh into hooks.PreToolUse"
else
    echo "FAIL: $SETTINGS does not reference scan-budget.sh in hooks.PreToolUse"
    fail=1
fi

exit "$fail"
