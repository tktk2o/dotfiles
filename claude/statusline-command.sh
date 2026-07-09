#!/bin/bash

input=$(cat)

R='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'

gradient() {
    local pct=$1
    if [ "$pct" -lt 50 ]; then
        local r=$((pct * 51 / 10))
        printf '\033[38;2;%d;200;80m' "$r"
    else
        local g=$((200 - (pct - 50) * 4))
        [ "$g" -lt 0 ] && g=0
        printf '\033[38;2;255;%d;60m' "$g"
    fi
}

dot() {
    local pct=$1
    printf '%b●%b %b%d%%%b' "$(gradient "$pct")" "$R" "$BOLD" "$pct" "$R"
}

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")

if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    case "$git_dir" in
        */worktrees/*) wt_marker=" ⎇" ;;
        *) wt_marker="" ;;
    esac
    git_info=" (${branch}${wt_marker})"
else
    git_info=""
fi

sep=$(printf ' %b·%b ' "$DIM" "$R")

parts="${dir_name}${git_info}${sep}$(printf '%b%s%b' "$BOLD" "$model" "$R")"

ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx" ]; then
    parts="${parts}${sep}ctx $(dot "$ctx")"
fi

# Subscription rate limits (.rate_limits.*) only appear for Claude.ai Pro/Max
# accounts; on API/console billing those fields are absent, so 5h/7d usage
# stopped rendering. We surface cost-based usage via ccusage instead.
#
# ccusage statusline emits " | "-separated segments:
#   🤖 model | 💰 cost | 🔥 burn rate | 🧠 context
# dir/git/model/ctx are already rendered above, so we append only the 💰 and 🔥
# segments to avoid duplication.
#
# Resolve ccusage without spawning npx on every render (slow): prefer a global
# binary, then the mise shim (works without `mise activate`), else fall back to
# npx. ccusage is declared in dotfiles/mise/config.toml as npm:ccusage.
if command -v ccusage > /dev/null 2>&1; then
    ccusage_cmd=(ccusage)
elif [ -x "$HOME/.local/share/mise/shims/ccusage" ]; then
    ccusage_cmd=("$HOME/.local/share/mise/shims/ccusage")
elif command -v npx > /dev/null 2>&1; then
    ccusage_cmd=(npx -y ccusage)
fi
if [ -n "${ccusage_cmd:-}" ]; then
    usage=$(echo "$input" | "${ccusage_cmd[@]}" statusline 2>/dev/null)
    if [ -n "$usage" ]; then
        cost=$(echo "$usage" | awk -F ' \\| ' '{for (i=1;i<=NF;i++) if ($i ~ /^💰/) print $i}')
        burn=$(echo "$usage" | awk -F ' \\| ' '{for (i=1;i<=NF;i++) if ($i ~ /^🔥/) print $i}')
        [ -n "$cost" ] && parts="${parts}${sep}${cost}"
        [ -n "$burn" ] && parts="${parts}${sep}${burn}"
    fi
fi

printf '%b' "$parts"
