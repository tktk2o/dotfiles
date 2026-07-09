#!/bin/bash
# Claude Code PostToolUse hook: lint/format feedback after edits.
#
# Fires after Edit / Write / MultiEdit. Runs a fast check on the edited file
# and, if it finds problems, injects them back to Claude as additionalContext
# (non-blocking — the file is already on disk; Claude decides whether to fix).
# Silent when the file is clean.
#
# Design constraints (this runs on EVERY edit):
#   - Only use tools that are already present; skip silently otherwise.
#   - Never spawn `npx` (too slow). Project linters are found via the nearest
#     node_modules/.bin instead.
#   - Cheap, universal checks (jq / gofmt / shell -n) are the reliable core.

input=$(cat)

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file" ] || [ ! -f "$file" ] && exit 0

# Walk up from the edited file to find a project-local binary in node_modules/.bin
find_local_bin() {
    local name="$1" dir
    dir=$(dirname "$file")
    while [ "$dir" != "/" ]; do
        if [ -x "$dir/node_modules/.bin/$name" ]; then
            printf '%s' "$dir/node_modules/.bin/$name"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

msg=""
add() { [ -n "$1" ] && msg="${msg}${msg:+$'\n'}$1"; }

case "$file" in
    *.json)
        err=$(jq empty "$file" 2>&1) || add "JSON syntax error in $(basename "$file"): $err"
        ;;
    *.sh|*.bash)
        err=$(bash -n "$file" 2>&1) || add "Shell syntax error: $err"
        command -v shellcheck >/dev/null 2>&1 && { out=$(shellcheck -f gcc "$file" 2>/dev/null); add "$out"; }
        ;;
    *.zsh)
        err=$(zsh -n "$file" 2>&1) || add "zsh syntax error: $err"
        ;;
    *.go)
        out=$(gofmt -l "$file" 2>/dev/null)
        [ -n "$out" ] && add "gofmt: $(basename "$file") is not formatted (run gofmt -w)."
        ;;
    *.lua)
        command -v stylua >/dev/null 2>&1 && { stylua --check "$file" >/dev/null 2>&1 || add "stylua: $(basename "$file") is not formatted."; }
        ;;
    *.py)
        bin=$(command -v ruff || true)
        [ -n "$bin" ] && { out=$("$bin" check --quiet "$file" 2>&1); add "$out"; }
        ;;
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
        if bin=$(find_local_bin biome); then
            out=$("$bin" lint "$file" 2>&1 | head -20)
            printf '%s' "$out" | grep -qiE 'error|warn' && add "$out"
        elif bin=$(find_local_bin eslint); then
            out=$("$bin" "$file" 2>&1 | head -20)
            [ -n "$out" ] && add "$out"
        fi
        ;;
esac

if [ -n "$msg" ]; then
    jq -cn --arg ctx "Lint/format feedback for $(basename "$file"):
$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
fi
exit 0
