#!/bin/bash
# Invariant: claude/hooks/guard-dotfiles.sh covers exactly the single-file
# symlinks that setup.sh creates — no more, no less.
#
# Why: the hook denies Write/Edit to a symlink's own path, because those tools
# replace-via-rename and would leave an orphan real file at the target, quietly
# dropping the edit out of the repo. The hook cannot discover the mapping at
# runtime (it must stay a jq-only, no-subprocess check that runs on every tool
# call), so the list is hardcoded — and a hardcoded list next to a growing
# setup.sh is a drift waiting to happen. A new `create_symlink` line would
# silently ship an unguarded path; a removed one would leave a stale deny that
# blocks editing a file the repo no longer owns.
#
# Only FILE symlinks are in scope. Whole-directory symlinks (nvim/,
# claude/hooks/, claude/skills/, claude/rules/, zsh/plugins/) are deliberately
# exempt: writing through a directory symlink lands inside the repo, so there
# is no drift risk and denying them would block ordinary work.

set -u

SETUP="setup.sh"
HOOK="claude/hooks/guard-dotfiles.sh"
fail=0

for f in "$SETUP" "$HOOK"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        exit 1
    fi
done

# --- setup.sh side: dests whose src is a regular file ---
expected=()
while IFS='|' read -r src dest; do
    rel="${src#\$DOTFILES_DIR/}"
    # A directory src is exempt (see header). An src that is missing entirely is
    # symlink_src_exists_test.sh's problem, not ours — skip rather than
    # double-report, except for the seeded gh-dash config which is a real file
    # target once setup has run.
    if [ -d "$rel" ]; then
        continue
    fi
    if [ ! -e "$rel" ] && [ "$rel" != "gh-dash/config.local.yml" ]; then
        continue
    fi
    expected+=("$dest")
done < <(grep -E '^[[:space:]]*create_symlink ' "$SETUP" |
    sed -E 's/.*create_symlink "([^"]*)" "([^"]*)".*/\1|\2/')

if [ "${#expected[@]}" -eq 0 ]; then
    echo "FAIL: extracted no file symlinks from $SETUP — extraction is broken"
    exit 1
fi

# --- hook side: the `"$home/..."` case patterns ---
guarded=()
while IFS= read -r pat; do
    guarded+=("$pat")
done < <(grep -oE '^[[:space:]]*"\$home/[^"]*"\)' "$HOOK" |
    sed -E 's/^[[:space:]]*"//; s/"\)$//')

if [ "${#guarded[@]}" -eq 0 ]; then
    echo "FAIL: extracted no guarded paths from $HOOK — extraction is broken"
    exit 1
fi

contains() { # <needle> <haystack...>
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# setup.sh uses "$HOME/...", the hook uses "$home/..." — normalize to compare.
for dest in "${expected[@]}"; do
    want="${dest/\$HOME\//\$home/}"
    if contains "$want" "${guarded[@]}"; then
        echo "OK: guarded $dest"
    else
        echo "FAIL: $SETUP symlinks $dest but $HOOK does not guard it"
        fail=1
    fi
done

for pat in "${guarded[@]}"; do
    want="${pat/\$home\//\$HOME/}"
    if ! contains "$want" "${expected[@]}"; then
        echo "FAIL: $HOOK guards $pat but $SETUP no longer symlinks it (stale deny)"
        fail=1
    fi
done

echo "checked ${#expected[@]} file symlinks against ${#guarded[@]} guarded paths"
exit "$fail"
