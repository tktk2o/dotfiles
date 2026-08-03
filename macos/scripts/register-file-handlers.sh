#!/bin/bash
# Point selected file extensions at "Open in Neovim.app".
#
# Deliberately NOT run by setup.sh: this changes system-wide defaults, so it
# stays an explicit, opt-in step you run once per machine.
#
# Extensions, not UTIs. Claiming `public.plain-text` would drag in far more than
# intended; a list of extensions is something you can read and predict.
#
# Usage:
#   register-file-handlers.sh            register every extension below
#   register-file-handlers.sh --list     show what is registered now
#   register-file-handlers.sh --revert   hand the extensions back to TextEdit

set -e

BUNDLE_ID="com.tktk2o.open-in-neovim"
FALLBACK_ID="com.apple.TextEdit"

# Text-ish things worth reading in an editor. Binary formats (pdf, images,
# archives, office documents) are left alone - Quick Look is faster for those.
EXTENSIONS=(
    txt md markdown
    json yaml yml toml xml
    csv tsv
    log diff patch
    sh bash zsh
    py ts tsx js jsx go rs
    sql tf hcl
    conf ini env
    lua vim
)

die() {
    echo "register-file-handlers: $1" >&2
    exit 1
}

command -v duti > /dev/null 2>&1 || die "duti is required (brew install duti)"

case "${1:-}" in
    --list)
        for ext in "${EXTENSIONS[@]}"; do
            printf '%-10s %s\n' "$ext" "$(duti -x "$ext" 2> /dev/null | tail -1 || echo '(none)')"
        done
        exit 0
        ;;
    --revert)
        target="$FALLBACK_ID"
        echo "Handing ${#EXTENSIONS[@]} extensions back to $FALLBACK_ID..."
        ;;
    '')
        target="$BUNDLE_ID"
        # A missing app would leave the extensions pointing at nothing, which
        # looks like a broken Finder rather than a missing step.
        [ -d "$HOME/Applications/Open in Neovim.app" ] ||
            die "'Open in Neovim.app' not found - run ./setup.sh first"
        echo "Pointing ${#EXTENSIONS[@]} extensions at $BUNDLE_ID..."
        ;;
    *)
        die "unknown option: $1"
        ;;
esac

for ext in "${EXTENSIONS[@]}"; do
    duti -s "$target" "$ext" all
done

echo "Done. Verify with: $0 --list"
echo "Finder may need a moment; a relaunch (killall Finder) forces the refresh."
