#!/bin/bash
# Invariant: claude/CLAUDE.md's @ imports resolve.
#
# Why: ~/.claude/CLAUDE.md is a symlink to claude/CLAUDE.md (setup.sh), and
# per CLAUDE.md's own long note, Claude Code resolves *relative* @ imports
# against the symlink's realpath (dotfiles/claude/), not against ~/.claude/.
# A bare relative import for a file that only exists under ~/.claude/ (like
# `@RTK.md` or `@local.md`) does not error — it silently resolves to nothing,
# and the personal instructions are just never loaded. This test checks both
# directions:
#   1. every relative import actually has a file next to claude/CLAUDE.md
#   2. the untracked-only files (RTK.md, local.md) are never imported via a
#      bare relative form — only via the absolute @~/.claude/... form

set -u

CLAUDE_MD="claude/CLAUDE.md"
fail=0

if [ ! -f "$CLAUDE_MD" ]; then
    echo "FAIL: $CLAUDE_MD not found"
    exit 1
fi

import_count=0
while IFS= read -r line; do
    import_count=$((import_count + 1))
    target="${line#@}"

    case "$target" in
        '~/'*)
            echo "OK: absolute import left for Claude Code to resolve against \$HOME: $line"
            ;;
        *)
            resolved="claude/$target"
            if [ -f "$resolved" ]; then
                echo "OK: relative import resolves: $line -> $resolved"
            else
                echo "FAIL: relative import does not resolve: $line (expected $resolved)"
                fail=1
            fi
            ;;
    esac
done < <(grep -E '^@' "$CLAUDE_MD")

if [ "$import_count" -eq 0 ]; then
    echo "FAIL: found no @ imports in $CLAUDE_MD — extraction regex is broken"
    fail=1
fi

# Guard against the exact silently-broken form the CLAUDE.md note warns about:
# a bare relative import of a file that only ever exists under ~/.claude/.
for untracked_only in "RTK.md" "local.md"; do
    if grep -qE "^@${untracked_only}\$" "$CLAUDE_MD"; then
        echo "FAIL: $CLAUDE_MD imports @${untracked_only} by bare relative path — it only exists under ~/.claude/ and must be imported as @~/.claude/${untracked_only}"
        fail=1
    fi
done

exit "$fail"
