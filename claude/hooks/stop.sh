#!/bin/bash
# Claude Code Stop Hook
# Triggered when Claude Code completes a task

osascript -e 'display notification "タスクが完了しました" with title "Claude Code" subtitle "処理終了" sound name "Hero"'
