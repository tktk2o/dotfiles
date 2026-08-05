#!/bin/bash
# Invariant: every create_symlink src argument in setup.sh points at a path
# that actually exists in this repo.
#
# Why: create_symlink does `rm -rf "$dest"` before `ln -s "$src" "$dest"`
# (setup.sh). If $src does not exist, ln still succeeds and quietly creates a
# dangling symlink at $dest, destroying whatever real file used to live
# there — and the breakage is invisible until something later tries to read
# through the link. This is a repo-content check only (it does not run
# setup.sh or touch $HOME); it just verifies the src half of every mapping.

set -u

fail=0
count=0

# gh-dash/config.local.yml is a documented exception: setup.sh seeds it from
# config.yml.example (cp, right before the create_symlink call) if it does
# not already exist, precisely because it is untracked and machine-local.
# So its absence in a repo checkout is expected, not a broken mapping.
SELF_SEEDED_EXCEPTIONS=("gh-dash/config.local.yml")

is_self_seeded_exception() { # <rel path>
    local rel="$1" ex
    for ex in "${SELF_SEEDED_EXCEPTIONS[@]}"; do
        [ "$rel" = "$ex" ] && return 0
    done
    return 1
}

# Extract each create_symlink call's first argument. Calls look like:
#   create_symlink "$DOTFILES_DIR/foo/bar" "$HOME/.bar"
# Grab the string between the first pair of quotes on each create_symlink line.
while IFS= read -r line; do
    # Strip everything up to and including `create_symlink "`.
    rest="${line#*create_symlink \"}"
    # First argument ends at the next unescaped double quote.
    src_raw="${rest%%\"*}"

    case "$src_raw" in
        '$DOTFILES_DIR/'*)
            rel="${src_raw#\$DOTFILES_DIR/}"
            ;;
        *)
            echo "FAIL: unrecognized create_symlink src form: $src_raw"
            fail=1
            continue
            ;;
    esac

    count=$((count + 1))
    if [ -e "$rel" ]; then
        echo "OK: $rel exists"
    elif is_self_seeded_exception "$rel"; then
        echo "SKIP: $rel (untracked, seeded by setup.sh itself before create_symlink runs)"
    else
        echo "FAIL: create_symlink src does not exist: $rel"
        fail=1
    fi
done < <(grep -E '^\s*create_symlink ' setup.sh)

if [ "$count" -eq 0 ]; then
    echo "FAIL: found no create_symlink calls in setup.sh — extraction regex is broken"
    fail=1
fi

exit "$fail"
