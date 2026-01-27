#!/bin/bash

# Claude Code notification hook
# Sends macOS notification when Claude needs input

read -r notification_data

notification_type=$(echo "$notification_data" | jq -r '.notification_type // empty')
message=$(echo "$notification_data" | jq -r '.message // empty')

case "$notification_type" in
  permission_prompt)
    osascript -e "display notification \"$message\" with title \"Claude Code\""
    afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
    ;;
  idle_prompt)
    osascript -e "display notification \"Awaiting your input\" with title \"Claude Code - Idle\""
    ;;
esac

exit 0
