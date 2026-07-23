#!/bin/bash

# dotfiles setup script
# Usage: ./setup.sh [--no-brew]
#
# Options:
#   --no-brew    Skip Homebrew installation and brew bundle

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_BREW=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-brew)
            SKIP_BREW=true
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
        echo "[Homebrew] Skipped. Some features may not work."
        return 1
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
    create_symlink "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
    create_symlink "$DOTFILES_DIR/sheldon/plugins.toml" "$HOME/.config/sheldon/plugins.toml"
    create_symlink "$DOTFILES_DIR/mise/config.toml" "$HOME/.config/mise/config.toml"
    create_symlink "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    create_symlink "$DOTFILES_DIR/gh/config.yml" "$HOME/.config/gh/config.yml"
    create_symlink "$DOTFILES_DIR/gh-dash/config.yml" "$HOME/.config/gh-dash/config.yml"
    create_symlink "$DOTFILES_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"

    # Executables (~/.local/bin — already on PATH via zsh/.zshrc)
    create_symlink "$DOTFILES_DIR/tmux/scripts/tmux-window-restore.sh" "$HOME/.local/bin/twr"

    # Claude Code
    create_symlink "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
    create_symlink "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
    create_symlink "$DOTFILES_DIR/claude/hooks" "$HOME/.claude/hooks"
    create_symlink "$DOTFILES_DIR/claude/skills" "$HOME/.claude/skills"
    create_symlink "$DOTFILES_DIR/claude/worktree.md" "$HOME/.claude/worktree.md"
    create_symlink "$DOTFILES_DIR/claude/model-policy.md" "$HOME/.claude/model-policy.md"

    # VSCode (macOS)
    if [ "$(uname)" = "Darwin" ]; then
        VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
        create_symlink "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
        create_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
    fi

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

    # Summary
    print_summary
}

main "$@"
