#!/bin/bash
# Invariant: claude_names (tmux-claude-rename.sh) numbers Claude panes the same
# way for the rename hook and for launch-time `claude -n`. Needs no tmux server.

set -u

# shellcheck source=/dev/null
source "tmux/scripts/tmux-claude-rename.sh"
fail=0

check() {
    local label="$1" want="$2" got="$3"
    if [ "$got" = "$want" ]; then
        echo "OK: $label"
    else
        echo "FAIL: $label"
        echo "  want: $(printf '%s' "$want" | tr '\n' '|')"
        echo "  got:  $(printf '%s' "$got" | tr '\n' '|')"
        fail=1
    fi
}

check "single claude pane takes the bare name" \
    "%1 work" \
    "$(printf '%%1 2.1.322\n' | claude_names work)"

check "second claude pane gets -2" \
    "$(printf '%%1 work\n%%2 work-2')" \
    "$(printf '%%1 claude\n%%2 2.1.322\n' | claude_names work)"

check "non-claude panes are skipped and do not consume a number" \
    "$(printf '%%2 work\n%%4 work-2')" \
    "$(printf '%%1 zsh\n%%2 claude\n%%3 nvim\n%%4 claude\n' | claude_names work)"

check "launching pane counts in pane order" \
    "$(printf '%%1 work\n%%2 work-2\n%%3 work-3')" \
    "$(printf '%%1 claude\n%%2 zsh\n%%3 claude\n' | claude_names work %2)"

check "launching pane alone gets the bare name" \
    "%1 work" \
    "$(printf '%%1 zsh\n' | claude_names work %1)"

check "window name with spaces and non-ASCII survives" \
    "$(printf '%%1 my 作業 win\n%%2 my 作業 win-2')" \
    "$(printf '%%1 claude\n%%2 zsh\n' | claude_names 'my 作業 win' %2)"

exit "$fail"
