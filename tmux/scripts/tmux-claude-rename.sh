#!/bin/bash
# Sync Claude Code session names to the tmux window name, so peer sessions can
# address each other by it (SendMessage).
#   tmux-claude-rename.sh <window_id>      after-rename-window hook: /rename live panes
#   tmux-claude-rename.sh --name-for <pane_id>   name for a claude about to launch there
# Claude panes report their version (e.g. 2.1.322) as pane_current_command.
set -e

# stdin: "<pane_id> <command>" lines in pane order. Emits "<pane_id> <name>" for
# each claude pane; $2 is a pane about to launch claude, still running a shell.
claude_names() {
    local name=$1 launching=${2:-} i=0 pane cmd target
    while read -r pane cmd; do
        [[ $pane == "$launching" || $cmd == claude || $cmd =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        i=$((i + 1))
        target=$name
        if ((i > 1)); then target="$name-$i"; fi
        printf '%s %s\n' "$pane" "$target"
    done
}

window_panes() {
    tmux list-panes -t "$1" -F '#{pane_id} #{pane_current_command}'
}

rename_window_panes() {
    local window=$1 name pane target
    name=$(tmux display-message -p -t "$window" '#{window_name}')
    while read -r pane target; do
        tmux send-keys -t "$pane" -l "/rename $target"
        tmux send-keys -t "$pane" Enter
    done < <(window_panes "$window" | claude_names "$name")
}

# An auto-renamed window ("zsh") carries no deliberate name, so print nothing.
name_for_pane() {
    local launching=$1 name pane target
    if [[ $(tmux display-message -p -t "$launching" '#{automatic-rename}') == 1 ]]; then return 0; fi
    name=$(tmux display-message -p -t "$launching" '#{window_name}')
    while read -r pane target; do
        if [[ $pane == "$launching" ]]; then printf '%s\n' "$target"; fi
    done < <(window_panes "$launching" | claude_names "$name" "$launching")
}

main() {
    case ${1:-} in
        --name-for) name_for_pane "${2:?usage: tmux-claude-rename.sh --name-for <pane_id>}" ;;
        *) rename_window_panes "${1:?usage: tmux-claude-rename.sh <window_id>}" ;;
    esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
