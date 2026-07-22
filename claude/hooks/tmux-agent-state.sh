#!/bin/bash
# Claude Code tmux Agent State Hook
# Reflects Claude's semantic state onto the tmux window that owns this pane via
# a per-window user option (@agent_state). The window name (#W) is never touched,
# so manual `prefix ,` naming is preserved. .tmux.conf renders @agent_state as an
# emoji prefix in the window-status list.
#
# Subagents (Task tool) also count as "working": SubagentStart/SubagentStop
# maintain a per-window counter (@agent_running). The main Stop only flips to
# "done" when no subagents are still running, so the window stays "working" while
# background subagents keep going after the main thread has yielded a turn.
#
# Usage: tmux-agent-state.sh <event>
#   start          UserPromptSubmit -> reset counter, state=working
#   subagent-start SubagentStart    -> counter++, state=working
#   subagent-stop  SubagentStop     -> counter--
#   blocked        Notification     -> state=blocked
#   stop           Stop (main)      -> counter>0 ? working : done
#   working|done   legacy aliases (set state directly)
#
# No-op when not running inside tmux (safe outside tmux / inside Herdr panes).

set -eu

event="${1:-}"

# Only act inside tmux.
[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

# Resolve the window that owns this pane. Failures are non-fatal (e.g. the pane
# is already gone) so the hook never blocks Claude.
window="$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)" || exit 0
[ -n "$window" ] || exit 0

set_state() { tmux set-option -w -t "$window" @agent_state "$1" 2>/dev/null || true; }
set_count() { tmux set-option -w -t "$window" @agent_running "$1" 2>/dev/null || true; }
get_count() {
  local c
  c="$(tmux show-options -w -v -t "$window" @agent_running 2>/dev/null)" || c=""
  case "$c" in
    '' | *[!0-9]*) echo 0 ;;
    *) echo "$c" ;;
  esac
}

case "$event" in
  start) # UserPromptSubmit: fresh main turn, clear any stale subagent count
    set_count 0
    set_state working
    ;;
  subagent-start)
    set_count "$(($(get_count) + 1))"
    set_state working
    ;;
  subagent-stop)
    n="$(($(get_count) - 1))"
    if [ "$n" -lt 0 ]; then n=0; fi
    set_count "$n"
    # Leave @agent_state as-is; the main Stop finalizes it to done.
    ;;
  blocked)
    set_state blocked
    ;;
  stop) # Stop (main agent): keep working while subagents are still running
    if [ "$(get_count)" -gt 0 ]; then
      set_state working
    else
      set_state done
    fi
    ;;
  working) set_state working ;;
  done) set_state done ;;
  *) exit 0 ;;
esac
