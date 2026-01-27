#!/bin/bash
# Claude Code Notification Hook
# Triggered when Claude Code is waiting for user permission

osascript -e 'display notification "Claude Codeが許可を求めています" with title "Claude Code" subtitle "確認待ち" sound name "Glass"'
