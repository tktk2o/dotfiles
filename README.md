# dotfiles

macOS用の設定ファイル管理リポジトリ

## 新しいPCへの移行手順

### 1. Homebrewをインストール

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

インストール後、表示される指示に従ってPATHを設定してください。

### 2. gitをインストール

```bash
brew install git
```

### 3. dotfilesをクローン

```bash
mkdir -p ~/src/github.com/tktk2o
cd ~/src/github.com/tktk2o
git clone https://github.com/tktk2o/dotfiles.git
cd dotfiles
```

### 4. セットアップスクリプトを実行

```bash
./setup.sh
```

以下のシンボリックリンクが作成されます:

| リンク先 | ソース |
|---------|--------|
| `~/.zshrc` | `zsh/.zshrc` |
| `~/.tmux.conf` | `tmux/.tmux.conf` |
| `~/.gitconfig` | `git/.gitconfig` |
| `~/.Brewfile` | `brew/.Brewfile` |
| `~/.config/zsh/plugins` | `zsh/plugins/` |
| `~/.config/nvim` | `nvim/` |
| `~/.config/ghostty/config` | `ghostty/config` |
| `~/.config/starship.toml` | `starship/starship.toml` |
| `~/.config/sheldon/plugins.toml` | `sheldon/plugins.toml` |
| `~/.config/karabiner/karabiner.json` | `karabiner/karabiner.json` |
| `~/.config/gh/config.yml` | `gh/config.yml` |
| `~/.config/gh-dash/config.yml` | `gh-dash/config.yml` |
| `~/.claude/settings.json` | `claude/settings.json` |
| `~/.claude/hooks` | `claude/hooks/` |
| `~/.claude/skills` | `claude/skills/` |
| `~/Library/.../Code/User/settings.json` | `vscode/settings.json` |
| `~/Library/.../Code/User/keybindings.json` | `vscode/keybindings.json` |

### 5. 残りのBrewパッケージをインストール

```bash
brew bundle --file=~/.Brewfile
```

### 6. ターミナルを再起動

設定を反映するためにターミナルを再起動してください。

## ディレクトリ構成

```
dotfiles/
├── brew/            # Homebrew Brewfile
├── claude/          # Claude Code設定 (hooks, skills)
├── gh/              # GitHub CLI設定
├── gh-dash/         # gh-dash設定
├── ghostty/         # ターミナルエミュレータ設定
├── git/             # Git設定
├── karabiner/       # キーボードカスタマイズ
├── nvim/            # Neovim (LazyVim) 設定
├── sheldon/         # zshプラグインマネージャ
├── starship/        # シェルプロンプト
├── tmux/            # ターミナルマルチプレクサ
├── vscode/          # VSCode設定
├── zsh/             # シェル設定 + plugins/
└── setup.sh         # セットアップスクリプト
```

## 主要ツール

- **シェル**: zsh + sheldon (プラグイン管理) + starship (プロンプト)
- **ターミナル**: Ghostty
- **エディタ**: Neovim (LazyVim) / VSCode
- **マルチプレクサ**: tmux (prefix: Ctrl+J)
- **キーボード**: Karabiner-Elements
- **AI**: Claude Code
