#!/bin/bash

# dotfiles setup script
# Usage: ./setup.sh [--no-brew] [--no-file-handlers]
#
# Options:
#   --no-brew             Skip Homebrew installation and brew bundle
#   --no-file-handlers    Do not offer to change macOS default file handlers

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_BREW=false
SKIP_FILE_HANDLERS=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-brew)
            SKIP_BREW=true
            shift
            ;;
        --no-file-handlers)
            SKIP_FILE_HANDLERS=true
            shift
            ;;
    esac
done

echo "============================================"
echo "  dotfiles setup"
echo "============================================"
echo ""
echo "Source: $DOTFILES_DIR"
echo ""

# ===========================================
# Phase 1: Homebrew
# ===========================================

install_homebrew() {
    if command -v brew &> /dev/null; then
        echo "[Homebrew] Already installed: $(brew --version | head -1)"
        return 0
    fi

    echo "[Homebrew] Not found."
    read -p "Install Homebrew? (y/N): " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "[Homebrew] Skipped. Continuing with symlink setup."
        return 0
    fi

    echo "[Homebrew] Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    echo "[Homebrew] Installed successfully."
}

# ===========================================
# Phase 2: Symlinks
# ===========================================

create_symlink() {
    local src="$1"
    local dest="$2"
    local dest_dir="$(dirname "$dest")"

    # Create destination directory if it doesn't exist
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi

    # Remove existing file/symlink if exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -rf "$dest"
    fi

    ln -s "$src" "$dest"
    echo "  $dest -> $src"
}

create_symlinks() {
    echo ""
    echo "[Symlinks] Creating..."

    # Home directory dotfiles
    create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
    create_symlink "$DOTFILES_DIR/git/.gitignore_global" "$HOME/.gitignore_global"
    create_symlink "$DOTFILES_DIR/brew/.Brewfile" "$HOME/.Brewfile"

    # ~/.config directory
    create_symlink "$DOTFILES_DIR/zsh/plugins" "$HOME/.config/zsh/plugins"
    create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
    # NVIM_APPNAME=peek — the lightweight profile Finder-opened files use
    create_symlink "$DOTFILES_DIR/nvim-peek" "$HOME/.config/peek"
    create_symlink "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
    create_symlink "$DOTFILES_DIR/sheldon/plugins.toml" "$HOME/.config/sheldon/plugins.toml"
    create_symlink "$DOTFILES_DIR/mise/config.toml" "$HOME/.config/mise/config.toml"
    create_symlink "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    create_symlink "$DOTFILES_DIR/gh/config.yml" "$HOME/.config/gh/config.yml"
    # gh-dash: the live config is machine-local (company-specific repo/org names,
    # kept untracked). Seed it from the tracked template on first run, then symlink.
    if [ ! -f "$DOTFILES_DIR/gh-dash/config.local.yml" ]; then
        cp "$DOTFILES_DIR/gh-dash/config.yml.example" "$DOTFILES_DIR/gh-dash/config.local.yml"
        echo "[gh-dash] Seeded config.local.yml from template — add company-specific sections there."
    fi
    create_symlink "$DOTFILES_DIR/gh-dash/config.local.yml" "$HOME/.config/gh-dash/config.yml"
    create_symlink "$DOTFILES_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"

    # Executables (~/.local/bin — already on PATH via zsh/.zshrc)
    #: 過去の tmux ウィンドウを resurrect 履歴から復元する（fzf）
    create_symlink "$DOTFILES_DIR/tmux/scripts/tmux-window-restore.sh" "$HOME/.local/bin/twr"

    # Claude Code
    create_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
    create_symlink "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
    create_symlink "$DOTFILES_DIR/claude/hooks" "$HOME/.claude/hooks"
    create_symlink "$DOTFILES_DIR/claude/skills" "$HOME/.claude/skills"
    create_symlink "$DOTFILES_DIR/claude/worktree.md" "$HOME/.claude/worktree.md"
    create_symlink "$DOTFILES_DIR/claude/model-policy.md" "$HOME/.claude/model-policy.md"
create_symlink "$DOTFILES_DIR/claude/persona-github.md" "$HOME/.claude/persona-github.md"

    echo "[Symlinks] Done."
}

# ===========================================
# Phase 3: Brew Bundle
# ===========================================

run_brew_bundle() {
    if ! command -v brew &> /dev/null; then
        echo "[Brew Bundle] Skipped (Homebrew not available)."
        return 0
    fi

    echo ""
    echo "[Brew Bundle] Installing packages from ~/.Brewfile..."
    brew bundle --file="$HOME/.Brewfile"
    echo "[Brew Bundle] Done."
}

# ===========================================
# Phase 4: Additional Setup
# ===========================================

setup_sheldon() {
    if ! command -v sheldon &> /dev/null; then
        echo "[sheldon] Skipped (sheldon not installed)."
        return 0
    fi

    echo ""
    echo "[sheldon] Cloning plugins..."
    sheldon lock --update
    echo "[sheldon] Done."
}

setup_git_hooks() {
    echo ""
    echo "[git hooks] Enabling pre-commit hook for the dotfiles repo (repo-local)..."
    # Repo-local so it never runs on work repos (which legitimately contain
    # company names and would false-positive).
    git -C "$DOTFILES_DIR" config --local core.hooksPath "$DOTFILES_DIR/git/hooks"
    chmod +x "$DOTFILES_DIR/git/hooks/pre-commit" 2>/dev/null || true

    local denylist="$HOME/.config/git/denylist.txt"
    if [ -f "$denylist" ]; then
        echo "[git hooks] Company denylist present: $denylist"
    else
        echo "[git hooks] NOTE: company-term denylist not found at:"
        echo "                $denylist"
        echo "            Create it (one grep -E regex per line) to enable"
        echo "            company-specific leak checks. It is intentionally NOT"
        echo "            tracked in this repo (the terms are themselves sensitive)."
    fi
}

setup_tmux_plugins() {
    if ! command -v tmux &> /dev/null; then
        echo "[tmux plugins] Skipped (tmux not installed)."
        return 0
    fi

    local tpm_dir="$HOME/.tmux/plugins/tpm"
    echo ""
    if [ ! -d "$tpm_dir" ]; then
        echo "[tmux plugins] Cloning TPM..."
        git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    else
        echo "[tmux plugins] TPM already present."
    fi

    # install_plugins reads ~/.tmux.conf (symlinked) for @plugin lines and
    # clones resurrect/continuum into ~/.tmux/plugins/. Non-fatal if it fails
    # (e.g. no network); plugins can also be installed later via `prefix + I`.
    echo "[tmux plugins] Installing plugins..."
    "$tpm_dir/bin/install_plugins" || echo "[tmux plugins] install_plugins failed; run 'prefix + I' inside tmux."
}

setup_gh_extensions() {
    if ! command -v gh &> /dev/null; then
        echo "[gh extensions] Skipped (gh not installed)."
        return 0
    fi

    echo ""
    echo "[gh extensions] Setting up..."

    if ! gh extension list 2>/dev/null | grep -q "dlvhdr/gh-dash"; then
        gh extension install dlvhdr/gh-dash
        echo "[gh extensions] Installed gh-dash."
    else
        echo "[gh extensions] gh-dash already installed."
    fi
}

# rtk filters token-heavy Bash output for Claude Code (wired via the
# PreToolUse hook in claude/settings.json). This step:
#   1. Runs `rtk init -g --no-patch` to install the rtk-managed
#      ~/.claude/RTK.md content file. We use --no-patch because both
#      settings.json and CLAUDE.md are fully managed by dotfiles.
#      ~/.claude/CLAUDE.md is a symlink to claude/CLAUDE.md, which already
#      contains the @RTK.md / @worktree.md / @model-policy.md imports, so
#      rtk's CLAUDE.md patching is a no-op.
#   2. Verifies project-local filters in .rtk/filters.toml are trusted.
#      Trusting must be done interactively by the user (`rtk trust`).
setup_rtk() {
    if ! command -v rtk &> /dev/null; then
        echo "[rtk] Skipped (rtk not installed)."
        return 0
    fi

    echo ""
    echo "[rtk] Running 'rtk init -g --no-patch' (installs ~/.claude/RTK.md)..."
    rtk init -g --no-patch

    local filters_path="$DOTFILES_DIR/.rtk/filters.toml"
    if [ ! -f "$filters_path" ]; then
        echo "[rtk] Skipped trust check (no $filters_path)."
        return 0
    fi

    echo "[rtk] Checking trust state..."
    if rtk trust --list 2>/dev/null | grep -qF "$filters_path"; then
        echo "[rtk] Project filters already trusted."
        return 0
    fi

    echo "[rtk] Project filters are NOT yet trusted on this machine."
    echo "      To enable filters (interactive confirm):"
    echo "          cd \"$DOTFILES_DIR\" && rtk trust"
    echo "      Verify with: rtk trust --list"
}

# csr is compiled rather than symlinked: it scans ~270MB of session logs and has
# to stay interactive, which a shell/jq pipeline cannot do (see claude/csr/).
setup_csr() {
    if ! command -v go &> /dev/null; then
        echo "[csr] Skipped (go not installed — 'brew bundle' installs it)."
        return 0
    fi

    echo ""
    echo "[csr] Building claude/csr -> ~/.local/bin/csr..."
    mkdir -p "$HOME/.local/bin"
    #: 過去の Claude セッションを自分の発言で検索して再開する（fzf）
    (cd "$DOTFILES_DIR/claude/csr" && go build -o "$HOME/.local/bin/csr" .)
    echo "[csr] Done. Search past Claude sessions with 'csr' or tmux 'prefix + F'."
}

# keys is the inventory of everything this repo lets you type; it reads the
# configs directly, so it lives with them rather than being generated once.
setup_keys() {
    if ! command -v go &> /dev/null; then
        echo "[keys] Skipped (go not installed — 'brew bundle' installs it)."
        return 0
    fi

    echo ""
    echo "[keys] Building tools/cheatsheet -> ~/.local/bin/keys..."
    mkdir -p "$HOME/.local/bin"
    #: この dotfiles が提供するコマンド / キーバインドを一覧・検索する（fzf）
    (cd "$DOTFILES_DIR/tools/cheatsheet" && go build -o "$HOME/.local/bin/keys" .)
    echo "[keys] Done. Browse commands with 'keys'; regenerate docs with 'keys --generate'."
}

# macOS hands files to .app bundles only, and as an Apple Event rather than as
# argv, so treating nvim as a file handler needs a wrapper app with an AppKit
# event loop. Swift, not Go: a bundled Go binary measured argc=0, and handling
# the event in-process saves the ~154ms an AppleScript applet spent on the OSA
# runtime plus a shell hop.
#
# Building the app is safe and idempotent. Pointing extensions at it changes
# system-wide defaults, so setup asks before doing that and defaults to No.
setup_macos_handlers() {
    [ "$(uname)" = "Darwin" ] || return 0

    if ! command -v swiftc &> /dev/null; then
        echo "[macOS] Skipped (swiftc not found — install Xcode Command Line Tools)."
        return 0
    fi

    local src="$DOTFILES_DIR/macos/nvim-open/main.swift"
    local app="$HOME/Applications/Open in Neovim.app"
    local bundle_id="com.tktk2o.open-in-neovim"

    echo ""
    echo "[macOS] Building nvim-open + 'Open in Neovim.app'..."
    mkdir -p "$HOME/.local/bin" "$app/Contents/MacOS"

    # Delete first: swiftc writes through a symlink, so a stale link left by an
    # earlier layout would put the binary wherever that link pointed (this
    # happened once, landing a compiled binary inside the repo).
    rm -f "$HOME/.local/bin/nvim-open"

    # One binary serves both roles: on PATH as a CLI, and inside the bundle.
    #: ファイルを nvim（peek プロファイル）で開く。Finder / ブラウザからの入口
    swiftc -O "$src" -o "$HOME/.local/bin/nvim-open"
    cp "$HOME/.local/bin/nvim-open" "$app/Contents/MacOS/nvim-open"

    # The bundle needs a stable identifier for duti to target, an Editor
    # document type before Finder will offer it as a default app, and
    # LSUIElement so opening a file does not bounce a dock icon. Written from
    # scratch each time, so re-running is a no-op.
    python3 - "$app/Contents/Info.plist" "$bundle_id" << 'PY'
import plistlib, sys

path, bundle_id = sys.argv[1], sys.argv[2]
plist = {
    'CFBundleName': 'Open in Neovim',
    'CFBundleDisplayName': 'Open in Neovim',
    'CFBundleIdentifier': bundle_id,
    'CFBundleExecutable': 'nvim-open',
    'CFBundlePackageType': 'APPL',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleShortVersionString': '1.0',
    'LSMinimumSystemVersion': '13.0',
    # Accessory app: no dock icon, no bounce.
    'LSUIElement': True,
    'CFBundleDocumentTypes': [{
        'CFBundleTypeName': 'AllFiles',
        'CFBundleTypeRole': 'Editor',
        'LSItemContentTypes': ['public.item'],
    }],
}
with open(path, 'wb') as f:
    plistlib.dump(plist, f)
PY

    # Without re-registering, Finder keeps serving the pre-patch bundle.
    local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    [ -x "$lsregister" ] && "$lsregister" -f "$app"

    echo "[macOS] Built: $app"
    if ! command -v duti &> /dev/null; then
        echo "        Install duti first ('brew bundle'), then run:"
        echo "            $DOTFILES_DIR/macos/scripts/register-file-handlers.sh"
        return 0
    fi

    if [ "$SKIP_FILE_HANDLERS" = true ]; then
        echo "[macOS] File-handler registration skipped (--no-file-handlers)."
        return 0
    fi

    local answer=""
    if ! read -r -p "Register supported text files (csv, md, json, etc.) with Neovim? (y/N): " answer; then
        echo ""
    fi
    if [[ "$answer" = "y" || "$answer" = "Y" ]]; then
        "$DOTFILES_DIR/macos/scripts/register-file-handlers.sh"
    else
        echo "[macOS] File-handler registration skipped. Run later with:"
        echo "        $DOTFILES_DIR/macos/scripts/register-file-handlers.sh"
    fi
}

# ===========================================
# Phase 4: Summary
# ===========================================

print_summary() {
    echo ""
    echo "============================================"
    echo "  Setup Complete!"
    echo "============================================"
    echo ""
    echo "Restart your terminal to apply changes."
    echo ""

    # Raycast
    if [ -d "$DOTFILES_DIR/raycast" ] && ls "$DOTFILES_DIR/raycast/"*.rayconfig &> /dev/null; then
        echo "Raycast: Import settings manually:"
        echo "  1. Open Raycast"
        echo "  2. Run 'Import Settings & Data' command"
        echo "  3. Select: $DOTFILES_DIR/raycast/*.rayconfig"
        echo ""
    fi

    if ! command -v brew &> /dev/null; then
        echo "Note: Homebrew was not installed."
        echo "  Run this script again after installing Homebrew manually:"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
    fi
}

# ===========================================
# Main
# ===========================================

main() {
    # Phase 1: Homebrew
    if [ "$SKIP_BREW" = false ]; then
        install_homebrew
    else
        echo "[Homebrew] Skipped (--no-brew)"
    fi

    # Phase 2: Symlinks
    create_symlinks

    # Phase 3: Brew Bundle
    if [ "$SKIP_BREW" = false ]; then
        run_brew_bundle
    else
        echo "[Brew Bundle] Skipped (--no-brew)"
    fi

    # Phase 4: Additional Setup
    setup_git_hooks
    setup_sheldon
    setup_tmux_plugins
    setup_gh_extensions
    setup_rtk
    setup_csr
    setup_keys
    setup_macos_handlers

    # Summary
    print_summary
}

main "$@"
