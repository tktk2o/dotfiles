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
    git_info=" ($branch)"
else
    git_info=""
fi

sep=$(printf ' %b·%b ' "$DIM" "$R")

parts="${dir_name}${git_info}${sep}$(printf '%b%s%b' "$BOLD" "$model" "$R")"

ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx" ]; then
    parts="${parts}${sep}ctx $(dot "$ctx")"
fi

five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five" ]; then
    parts="${parts}${sep}5h $(dot "$five")"
fi

week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$week" ]; then
    parts="${parts}${sep}7d $(dot "$week")"
fi

printf '%b' "$parts"
