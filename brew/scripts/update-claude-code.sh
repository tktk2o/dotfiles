#!/bin/bash
# Auto-update claude-code via Homebrew
# Scheduled by launchd (weekdays at 09:30)

set -e

# Set PATH for Homebrew (Intel and Apple Silicon)
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

LOG_FILE="$HOME/scripts/update-claude-code.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

{
    echo "=== $TIMESTAMP ==="
    brew update
    brew upgrade claude-code 2>&1 || echo "claude-code is already up to date"
    echo ""
} >> "$LOG_FILE" 2>&1
