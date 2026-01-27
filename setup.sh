#!/bin/bash

# dotfiles setup script
# Usage: ./setup.sh

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Setting up dotfiles from: $DOTFILES_DIR"

# Create symlink function
create_symlink() {
    local src="$1"
    local dest="$2"
    local dest_dir="$(dirname "$dest")"

    # Create destination directory if it doesn't exist
    if [ ! -d "$dest_dir" ]; then
        echo "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi

    # Remove existing file/symlink if exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        echo "Removing existing: $dest"
        rm -rf "$dest"
    fi

    echo "Linking: $dest -> $src"
    ln -s "$src" "$dest"
}

# Home directory dotfiles
create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
create_symlink "$DOTFILES_DIR/.ideavimrc" "$HOME/.ideavimrc"
create_symlink "$DOTFILES_DIR/brew/.Brewfile" "$HOME/.Brewfile"

# ~/.config directory
create_symlink "$DOTFILES_DIR/zsh/plugins" "$HOME/.config/zsh/plugins"
create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
create_symlink "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
create_symlink "$DOTFILES_DIR/sheldon/plugins.toml" "$HOME/.config/sheldon/plugins.toml"
create_symlink "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
create_symlink "$DOTFILES_DIR/gh/config.yml" "$HOME/.config/gh/config.yml"
create_symlink "$DOTFILES_DIR/gh-dash/config.yml" "$HOME/.config/gh-dash/config.yml"

# Claude Code
create_symlink "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
create_symlink "$DOTFILES_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
create_symlink "$DOTFILES_DIR/claude/hooks" "$HOME/.claude/hooks"
create_symlink "$DOTFILES_DIR/claude/skills" "$HOME/.claude/skills"

# VSCode (macOS)
if [ "$(uname)" = "Darwin" ]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    create_symlink "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
    create_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
fi

# GitHub CLI extensions
if command -v gh &> /dev/null; then
    if ! gh extension list | grep -q "dlvhdr/gh-dash"; then
        echo "Installing gh-dash extension..."
        gh extension install dlvhdr/gh-dash
    else
        echo "gh-dash already installed"
    fi
else
    echo "Note: gh not found. Install gh first, then run: gh extension install dlvhdr/gh-dash"
fi

echo ""
echo "Done! Symlinks created successfully."
echo ""
echo "Next steps:"
echo "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
echo "  2. Install packages: brew bundle --file=~/.Brewfile"
echo "  3. Install gh extensions: gh extension install dlvhdr/gh-dash"
echo "  4. Restart your terminal"
