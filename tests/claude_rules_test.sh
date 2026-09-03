#!/bin/bash
# Invariant: claude/rules/ stays a valid, correctly-costed always-on tier.
#
# Why: claude/rules/ is symlinked to ~/.claude/rules, which Claude Code loads
# automatically in every session on the machine, at CLAUDE.md priority. Two
# things fail silently here, and both already happened once:
#
#   1. A path named in prose ("read `~/.claude/rules/coding-style.md`") is not
#      an @ import, so nothing validates it. Rename or move the file and the
#      instruction keeps pointing at nothing — no error, no warning, and Claude
#      simply never sees the rule. The @-import test cannot catch this because
#      the reference is a backticked string, not an @ line.
#   2. A rules file without `paths:` frontmatter is always-on. Both files here
#      were documented as costing nothing until their topic came up, while
#      actually sitting in every session's context (197 lines). So the docs must
#      keep stating the real always-on total, and this test pins the arithmetic
#      to the files on disk.
#
# What this does NOT check: whether `paths:` frontmatter actually fires on a
# Write to a not-yet-existing file. That is undocumented upstream and needs a
# live session to measure — see config-maintenance.md.

set -u

RULES_DIR="claude/rules"
CONFIG_DOC="$RULES_DIR/config-maintenance.md"
fail=0

if [ ! -d "$RULES_DIR" ]; then
    echo "FAIL: $RULES_DIR not found"
    exit 1
fi

# 1. every ~/.claude/... path mentioned in the always-on instruction files must
#    exist, since a stale one degrades to silence rather than an error.
#    Every tilde below is literal text — a grep pattern, or a case label matched
#    against a string pulled out of a file — never a path to expand.
# shellcheck disable=SC2088
for src in claude/CLAUDE.md CLAUDE.md "$RULES_DIR"/*.md; do
    [ -f "$src" ] || continue
    while IFS= read -r ref; do
        # ~/.claude/<x> maps to claude/<x> in this repo. Three kinds of
        # reference are legitimately absent from it and must not fail:
        #   - untracked local files (see the Local-only table in CLAUDE.md)
        #   - runtime state Claude Code owns (session logs)
        #   - CLAUDE.local.md, named only to say the mechanism does not exist
        case "$ref" in
            '~/.claude/RTK.md' | '~/.claude/local.md' | '~/.claude/local/'* | \
            '~/.claude/settings.local.json' | '~/.claude/agents/'* | \
            '~/.claude/projects' | '~/.claude/projects/'* | \
            '~/.claude/CLAUDE.local.md')
                continue
                ;;
        esac
        resolved="claude/${ref#\~/.claude/}"
        if [ -e "$resolved" ]; then
            echo "OK: $src references an existing path: $ref"
        else
            echo "FAIL: $src references a path that does not exist: $ref (expected $resolved)"
            fail=1
        fi
    done < <(grep -oE '~/\.claude/[A-Za-z0-9._/-]+' "$src" | sort -u)
done

# 2. the measured always-on total in config-maintenance.md must match reality.
#    Counted here: the two tracked @ imports, claude/CLAUDE.md itself, and every
#    rules file with no `paths:` frontmatter. RTK.md and local.md are untracked
#    (absent on a fresh clone), so their documented 29 + 31 is taken on trust.
untracked_documented=$((29 + 31))
tracked_total=0
for f in claude/worktree.md claude/model-policy.md claude/CLAUDE.md; do
    if [ ! -f "$f" ]; then
        echo "FAIL: expected always-on file missing: $f"
        fail=1
        continue
    fi
    tracked_total=$((tracked_total + $(wc -l <"$f")))
done

for f in "$RULES_DIR"/*.md; do
    [ -f "$f" ] || continue
    # a rules file is lazy only if it declares paths: in frontmatter
    if head -5 "$f" | grep -qE '^paths:'; then
        echo "OK: $f is paths-gated (not counted as always-on)"
    else
        echo "OK: $f is always-on ($(wc -l <"$f") lines)"
        tracked_total=$((tracked_total + $(wc -l <"$f")))
    fi
done

actual_total=$((tracked_total + untracked_documented))
# the doc states this as a bolded, single-line "**583 lines** of global
# always-on" — kept in that exact form so this stays a one-pattern grep
documented_total=$(grep -oE '\*\*[0-9]+ lines\*\* of global always-on' "$CONFIG_DOC" |
    grep -oE '[0-9]+' | head -1)

if [ -z "${documented_total:-}" ]; then
    echo "FAIL: could not find the documented always-on total in $CONFIG_DOC"
    fail=1
elif [ "$documented_total" = "$actual_total" ]; then
    echo "OK: documented always-on total matches disk: $actual_total lines"
else
    echo "FAIL: always-on total drifted — $CONFIG_DOC says $documented_total, disk says $actual_total"
    echo "      (re-run the wc -l one-liner in that file's 'Detecting bloat' section and update it)"
    fail=1
fi

# 3. no leftover experiment files in the always-on tier
for f in "$RULES_DIR"/_*.md; do
    [ -f "$f" ] || continue
    echo "FAIL: temporary/experiment rule left in $RULES_DIR: $f (delete it — rules/ is always-on)"
    fail=1
done

exit "$fail"
