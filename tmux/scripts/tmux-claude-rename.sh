#!/bin/bash
# Sync Claude Code session names to the tmux window name, so peer sessions can
# address each other by it (SendMessage). Run from the after-rename-window hook.
# Claude panes report their version (e.g. 2.1.322) as pane_current_command.
set -e

window=${1:?usage: tmux-claude-rename.sh <window_id>}
name=$(tmux display-message -p -t "$window" '#{window_name}')

i=0
while read -r pane cmd; do
	[[ $cmd == claude || $cmd =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
	i=$((i + 1))
	target=$name
	((i > 1)) && target="$name-$i"
	tmux send-keys -t "$pane" -l "/rename $target"
	tmux send-keys -t "$pane" Enter
done < <(tmux list-panes -t "$window" -F '#{pane_id} #{pane_current_command}')
