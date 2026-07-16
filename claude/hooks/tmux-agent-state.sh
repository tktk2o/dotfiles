#!/bin/bash
# Claude Code tmux Agent State Hook
# Reflects Claude's semantic state onto the tmux window that owns this pane via
# a per-window user option (@agent_state). The window name (#W) is never touched,
# so manual `prefix ,` naming is preserved. .tmux.conf renders @agent_state as an
# emoji prefix in the window-status list.
#
# Usage: tmux-agent-state.sh <working|blocked|done>
# No-op when not running inside tmux (safe outside tmux / inside Herdr panes).

set -eu

state="${1:-}"

# Only act inside tmux, and only for known states.
[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0
case "$state" in
  working | blocked | done) ;;
  *) exit 0 ;;
esac

# Resolve the window that owns this pane, then tag it. Failures are non-fatal
# (e.g. the pane is already gone) so the hook never blocks Claude.
window="$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)" || exit 0
[ -n "$window" ] || exit 0
tmux set-option -w -t "$window" @agent_state "$state" 2>/dev/null || true
