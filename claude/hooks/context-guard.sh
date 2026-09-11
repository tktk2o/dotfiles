#!/bin/bash
# UserPromptSubmit hook: report the main thread's context size once per band,
# so /clear is a measured call. Port of iwasa-kosui/dotfiles context-guard.ts.
set -u

TAIL_BYTES=2000000

# tokens from the last main-thread assistant usage entry in a transcript, or empty
current_context_tokens() {
    local path="$1"
    tail -c "$TAIL_BYTES" "$path" 2>/dev/null |
        jq -R 'fromjson? | select(.type == "assistant" and (.isSidechain != true) and .message.usage) |
            (.message.usage.input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0)' |
        tail -n 1
}

# band = how many warn_step-sized steps past threshold; empty when below threshold
band_for_tokens() {
    local tokens="$1" threshold="$2" step="$3"
    [ "$tokens" -lt "$threshold" ] && return 1
    echo $(((tokens - threshold) / step))
}

# emit only when this band is strictly newer than the stored one
should_emit() {
    local band="$1" prev="${2:-}"
    case "$prev" in '' | *[!0-9]*) prev=-1 ;; esac
    [ "$band" -gt "$prev" ]
}

warn_message() {
    local tokens="$1"
    local k=$((tokens / 1000))
    printf 'Current context is roughly %sk tokens, and every tool call re-reads all of it at the main model'"'"'s rate. If the work is at a natural boundary, run /clear and restart with the learnings baked in (see model-policy.md'"'"'s "Context hygiene"). Otherwise, keep further reads and scans in subagents and stop loading file bodies onto this thread.' "$k"
}

main() {
    local input session_id transcript_path
    input=$(cat)
    session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
    [ -n "$session_id" ] && [ -n "$transcript_path" ] || exit 0
    [ -f "$transcript_path" ] || exit 0

    local threshold="${CLAUDE_CONTEXT_WARN_TOKENS:-200000}"
    local step="${CLAUDE_CONTEXT_WARN_STEP:-100000}"
    case "$threshold" in '' | *[!0-9]*) threshold=200000 ;; esac
    case "$step" in '' | *[!0-9]*) step=100000 ;; esac

    local tokens
    tokens=$(current_context_tokens "$transcript_path")
    case "$tokens" in '' | *[!0-9]*) exit 0 ;; esac

    local band
    band=$(band_for_tokens "$tokens" "$threshold" "$step") || exit 0

    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude/context-guard"
    mkdir -p "$state_dir" 2>/dev/null
    find "$state_dir" -type f -mtime +2 -delete 2>/dev/null

    local sanitized_id
    sanitized_id=$(printf '%s' "$session_id" | tr -c 'A-Za-z0-9._-' '_')
    local state_file="$state_dir/$sanitized_id"
    local prev=""
    [ -f "$state_file" ] && prev=$(cat "$state_file" 2>/dev/null)

    should_emit "$band" "$prev" || exit 0
    printf '%s' "$band" >"$state_file"

    jq -cn --arg ctx "$(warn_message "$tokens")" \
        '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
}

main 2>/dev/null || exit 0
