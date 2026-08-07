#!/bin/bash
# Invariant: none of the claude-launching entry points wrap `claude` in a
# `caffeinate` call.
#
# Why this direction, not the opposite: CLAUDE.md's "Sleep prevention is
# Claude Code's job, not this repo's" section documents that a caffeinate
# wrapper was added (commit "Hold off idle sleep for as long as Claude is
# running") and then reverted (commit "Drop the caffeinate wrappers; Claude
# Code already inhibits sleep") because Claude Code itself already spawns
# `caffeinate -i -t 300` and keeps renewing it — a repo-side wrapper is
# redundant at best, and actively worse at worst: `caffeinate -i claude`
# holds the sleep assertion for as long as the pane lives, so a pane left
# open for days would keep the machine awake forever, which the built-in,
# self-expiring inhibitor does not do. This test exists so that revert does
# not silently get undone by a future edit to any of these files.
#
# Scope: the five entry points named in CLAUDE.md's history of this decision.
# gh-dash/config.local.yml is untracked and machine-local — checked only if
# present, skipped (not failed) when absent, since a fresh clone won't have it.

set -u

fail=0

check_no_caffeinate() { # <path>
    local path="$1"
    if [ ! -f "$path" ]; then
        echo "SKIP: $path (not present)"
        return 0
    fi
    if grep -qi 'caffeinate' "$path"; then
        echo "FAIL: $path mentions caffeinate — the wrapper was intentionally reverted (see CLAUDE.md)"
        fail=1
    else
        echo "OK: $path has no caffeinate wrapper"
    fi
}

check_no_caffeinate "zsh/.zshrc"
check_no_caffeinate "zsh/plugins/dev.zsh"
check_no_caffeinate "gh-dash/config.yml.example"
check_no_caffeinate "gh-dash/config.local.yml" # untracked; skipped if absent
check_no_caffeinate "tmux/scripts/tmux-window-restore.sh"
check_no_caffeinate "claude/csr/main.go"

exit "$fail"
