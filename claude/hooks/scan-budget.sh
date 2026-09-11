#!/bin/bash
# Nudges (never denies) when the main thread piles up scan-style Bash calls
# instead of delegating them to a haiku subagent — see model-policy.md.
set -u

input=$(cat)

agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
[ -n "$agent_id" ] && exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$tool" = "Bash" ] || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)

# strip a leading `rtk `, env-var assignments, and `sudo` so the underlying
# command is what gets classified, not its wrapper
strip_prefix() {
    local seg="$1"
    seg="${seg#"${seg%%[![:space:]]*}"}"
    while true; do
        case "$seg" in
            rtk\ *) seg="${seg#rtk }" ;;
            sudo\ *) seg="${seg#sudo }" ;;
            [A-Za-z_][A-Za-z0-9_]*=*\ *)
                seg="${seg#*=*[[:space:]]}"
                ;;
            *) break ;;
        esac
        seg="${seg#"${seg%%[![:space:]]*}"}"
    done
    printf '%s' "$seg"
}

is_scan_segment() {
    local seg
    seg=$(strip_prefix "$1")
    local first second
    first=$(printf '%s' "$seg" | awk '{print $1}')
    second=$(printf '%s' "$seg" | awk '{print $2}')
    case "$first" in
        grep | rg | find | fd | ls | wc | jq | awk | cat | head | tail | \
            python3 | python | curl | wget | rtk)
            return 0
            ;;
        sed)
            printf '%s' "$seg" | grep -qE '(^|[[:space:]])-n([[:space:]]|$)' &&
                ! printf '%s' "$seg" | grep -qE '(^|[[:space:]])-i([[:space:]]|$)' &&
                return 0
            return 1
            ;;
        gh)
            case "$second" in
                run | api) return 0 ;;
            esac
            printf '%s' "$seg" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(diff|view)\b' && return 0
            return 1
            ;;
        git)
            case "$second" in
                log | show | grep | diff) return 0 ;;
            esac
            return 1
            ;;
        *) return 1 ;;
    esac
}

is_scan_command() {
    local cmd_str="$1" seg
    while IFS= read -r seg; do
        is_scan_segment "$seg" && return 0
    done <<<"$(printf '%s' "$cmd_str" | tr '|' '\n')"
    return 1
}

is_scan_command "$cmd" || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude/scan-budget"
mkdir -p "$state_dir" 2>/dev/null
find "$state_dir" -type f -mtime +2 -delete 2>/dev/null

# session_id comes from untrusted JSON; keep it from escaping state_dir
counter_file="$state_dir/$(printf '%s' "$session_id" | tr -c 'A-Za-z0-9._-' '_')"

bump_counter() {
    local file="$1" count=0
    [ -f "$file" ] && count=$(cat "$file" 2>/dev/null)
    case "$count" in '' | *[!0-9]*) count=0 ;; esac
    count=$((count + 1))
    printf '%s' "$count" >"$file"
    printf '%s' "$count"
}

new_count=$(bump_counter "$counter_file")

threshold="${CLAUDE_SCAN_BUDGET:-12}"
case "$threshold" in '' | *[!0-9]*) threshold=12 ;; esac

if [ "$threshold" -gt 0 ] && [ $((new_count % threshold)) -eq 0 ]; then
    jq -cn --arg ctx "This session has run $new_count scan-style Bash commands (grep/rg/find/jq/cat/python3/etc.) directly on the main thread. Delegate further scanning to a haiku subagent that returns only conclusions and file:line references, per model-policy.md's 'Delegation triggers' section, instead of piling more raw output into this context." \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
fi

exit 0
