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

## RTK (Bash-output token filter for Claude Code)

`rtk` (installed via `brew/.Brewfile`) compacts Bash tool output before it reaches the model. It is wired through the `PreToolUse` hook in `claude/settings.json` as the command `rtk hook claude` — no custom shim script is used (earlier versions of this repo had a `claude/hooks/rtk-rewrite.sh` wrapper; that has been removed).

### Layout

- **Binary**: `brew "rtk"` in `brew/.Brewfile`
- **Hook registration**: `claude/settings.json` → `hooks.PreToolUse[].hooks[].command = "rtk hook claude"`
- **Project filters**: `.rtk/filters.toml` (committed, currently just the stub template)

### New-machine migration

After `./setup.sh` + `brew bundle`, project filters must be trusted once per machine (rtk refuses to apply untrusted project filters for security):

```bash
cd ~/src/github.com/tktk2o/dotfiles && rtk trust
```

`setup.sh` prints this reminder when filters are not yet trusted; it cannot run the command automatically because `rtk trust` is interactive by design.

### Health check (for future Claude sessions)

If any of these fail, rtk is misconfigured:

```bash
command -v rtk                                  # binary is on PATH
rtk trust --list | grep dotfiles/.rtk           # this repo's filters are trusted
ls -la ~/.claude/settings.json                  # symlink to dotfiles/claude/settings.json
grep 'rtk hook claude' ~/.claude/settings.json  # correct hook command is wired
```

Symptom of forgotten `rtk trust`: every Bash tool result starts with `[rtk] WARNING: untrusted project filters (.rtk/filters.toml)`. That noise also corrupts downstream parsing of tool output.

RTK moves fast; if the commands or CLI surface above have changed, prefer `rtk --help` / `rtk trust --help` over blindly trusting this doc.
