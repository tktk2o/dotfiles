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
create_symlink "$DOTFILES_DIR/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
create_symlink "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
create_symlink "$DOTFILES_DIR/sheldon/plugins.toml" "$HOME/.config/sheldon/plugins.toml"
create_symlink "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"

# VSCode (macOS)
if [ "$(uname)" = "Darwin" ]; then
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    create_symlink "$DOTFILES_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
    create_symlink "$DOTFILES_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
fi

echo ""
echo "Done! Symlinks created successfully."
echo ""
echo "Next steps:"
echo "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
echo "  2. Install packages: brew bundle --file=~/.Brewfile"
echo "  3. Restart your terminal"
