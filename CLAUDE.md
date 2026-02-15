# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

macOS dotfiles management repository using symbolic links. Configurations are organized by tool in subdirectories and linked to appropriate locations by `setup.sh`.

## Setup Commands

```bash
# Clone and setup (after Homebrew + git are installed)
mkdir -p ~/src/github.com/tktk2o && cd ~/src/github.com/tktk2o
git clone https://github.com/tktk2o/dotfiles.git && cd dotfiles
./setup.sh                          # Creates all symlinks
brew bundle --file=~/.Brewfile      # Install packages
```

## Architecture

### Symlink Structure

`setup.sh` creates these symlinks:

| Source (dotfiles/) | Target |
|-------------------|--------|
| `zsh/.zshrc` | `~/.zshrc` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `git/.gitconfig` | `~/.gitconfig` |
| `.ideavimrc` | `~/.ideavimrc` |
| `brew/.Brewfile` | `~/.Brewfile` |
| `nvim/` | `~/.config/nvim` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` |
| `karabiner/karabiner.json` | `~/.config/karabiner/karabiner.json` |
| `gh/config.yml` | `~/.config/gh/config.yml` |
| `gh-dash/config.yml` | `~/.config/gh-dash/config.yml` |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `vscode/keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` |

### Neovim (LazyVim)

Located in `nvim/`, using LazyVim framework:
- `lua/config/options.lua` - Editor settings (2-space tabs)
- `lua/config/keymaps.lua` - Custom keybindings
- `lua/plugins/` - Plugin configurations

### PR Review Workflow

GitHub PR review integrates gh-dash with Neovim:

```bash
gh dash  # Start dashboard
# Keybindings: d=DiffviewOpen, C=Octo edit, o=browser, m=merge, a=approve
```

Neovim leader keys: `<leader>gpl` (list PRs), `<leader>gpr` (review), `<leader>gpm` (merge)

### Theme

Dracula color scheme across all tools (tmux, starship, Ghostty, VSCode, Neovim).

## Key Tools

- **Shell**: zsh + sheldon (plugin manager) + starship (prompt)
- **Terminal**: Ghostty
- **Multiplexer**: tmux (prefix: Ctrl+B)
- **Editor**: Neovim with LazyVim, octo.nvim, diffview.nvim
- **Project navigation**: ghq + fzf (`fgh` function in .zshrc)

## Adding New Configurations

1. Create subdirectory: `mkdir toolname/`
2. Add config file(s) to the subdirectory
3. Add symlink command to `setup.sh`
4. If installable via Homebrew, add to `brew/.Brewfile`
