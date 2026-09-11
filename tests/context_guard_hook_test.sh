#!/bin/bash
# Invariant: context-guard.sh nudges once per band above threshold, ignores
# sidechain usage, and never fails a prompt. Why: CLAUDE.md, "Guarded operations".

set -u

HOOK="claude/hooks/context-guard.sh"
SETTINGS="claude/settings.json"
fail=0

run_hook() {
    local state_dir="$1" transcript="$2" session="$3"
    jq -cn --arg t "$transcript" --arg s "$session" '{session_id: $s, transcript_path: $t}' |
        XDG_STATE_HOME="$state_dir" CLAUDE_CONTEXT_WARN_TOKENS=1000 CLAUDE_CONTEXT_WARN_STEP=500 bash "$HOOK"
}

write_transcript() {
    local path="$1" main_tokens="$2" side_tokens="${3:-}"
    {
        echo '{"type":"user","message":{"role":"user","content":"hi"}}'
        echo "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":$main_tokens,\"cache_creation_input_tokens\":0,\"cache_read_input_tokens\":0}}}"
        if [ -n "$side_tokens" ]; then
            echo "{\"type\":\"assistant\",\"isSidechain\":true,\"message\":{\"usage\":{\"input_tokens\":$side_tokens,\"cache_creation_input_tokens\":0,\"cache_read_input_tokens\":0}}}"
        fi
    } >"$path"
}

tmp_a="$(mktemp -d)"
out=$(run_hook "$tmp_a" "$tmp_a/missing.jsonl" "sa")
if [ -z "$out" ]; then
    echo "OK: missing transcript_path arg produces no output"
else
    echo "FAIL: missing transcript_path produced output: '$out'"
    fail=1
fi

tmp_b="$(mktemp -d)"
out=$(printf '%s' '{"session_id":"sb"}' | XDG_STATE_HOME="$tmp_b" CLAUDE_CONTEXT_WARN_TOKENS=1000 CLAUDE_CONTEXT_WARN_STEP=500 bash "$HOOK")
if [ -z "$out" ]; then
    echo "OK: no transcript_path key produces no output"
else
    echo "FAIL: absent transcript_path key produced output: '$out'"
    fail=1
fi

tmp_c="$(mktemp -d)"
write_transcript "$tmp_c/t.jsonl" 900
out=$(run_hook "$tmp_c" "$tmp_c/t.jsonl" "sc")
if [ -z "$out" ]; then
    echo "OK: 900 tokens (below 1000 threshold) produces no output"
else
    echo "FAIL: below-threshold usage produced output: '$out'"
    fail=1
fi

tmp_d="$(mktemp -d)"
write_transcript "$tmp_d/t.jsonl" 1200
out=$(run_hook "$tmp_d" "$tmp_d/t.jsonl" "sd")
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
if [ -n "$ctx" ] && [ "$ctx" != "null" ] && printf '%s' "$ctx" | grep -q '1k'; then
    echo "OK: 1200 tokens crosses the threshold and mentions '1k'"
else
    echo "FAIL: 1200-token usage did not warn as expected: '$out'"
    fail=1
fi

out2=$(run_hook "$tmp_d" "$tmp_d/t.jsonl" "sd")
if [ -z "$out2" ]; then
    echo "OK: same session, same band produces no repeat output"
else
    echo "FAIL: same band re-warned: '$out2'"
    fail=1
fi

write_transcript "$tmp_d/t2.jsonl" 1800
out3=$(run_hook "$tmp_d" "$tmp_d/t2.jsonl" "sd")
ctx3=$(printf '%s' "$out3" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)
if [ -n "$ctx3" ] && [ "$ctx3" != "null" ]; then
    echo "OK: same session, next band (1800 tokens) warns again"
else
    echo "FAIL: next-band usage did not re-warn: '$out3'"
    fail=1
fi

tmp_g="$(mktemp -d)"
write_transcript "$tmp_g/t.jsonl" 900 99999
out=$(run_hook "$tmp_g" "$tmp_g/t.jsonl" "sg")
if [ -z "$out" ]; then
    echo "OK: trailing sidechain usage is ignored in favor of the last main-thread entry"
else
    echo "FAIL: sidechain usage was counted: '$out'"
    fail=1
fi

tmp_h="$(mktemp -d)"
out=$(run_hook "$tmp_h" "$tmp_h/does-not-exist.jsonl" "sh")
if [ -z "$out" ]; then
    echo "OK: nonexistent transcript file produces no output"
else
    echo "FAIL: nonexistent transcript file produced output: '$out'"
    fail=1
fi

if jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command // empty' "$SETTINGS" 2>/dev/null | grep -q 'context-guard.sh'; then
    echo "OK: $SETTINGS wires context-guard.sh into hooks.UserPromptSubmit"
else
    echo "FAIL: $SETTINGS does not reference context-guard.sh in hooks.UserPromptSubmit"
    fail=1
fi

exit "$fail"
