# dotfiles

macOS用の設定ファイル管理リポジトリ

## 新しいPCへの移行手順

### 1. dotfilesをクローン

```bash
# gitはmacOSに同梱されています（Xcode Command Line Tools）
mkdir -p ~/src/github.com/tktk2o
cd ~/src/github.com/tktk2o
git clone https://github.com/tktk2o/dotfiles.git
cd dotfiles
```

### 2. セットアップスクリプトを実行

```bash
./setup.sh
```

このスクリプトは以下を自動で行います:

1. **Homebrew**: 未インストールの場合、インストールを提案
2. **シンボリックリンク**: 設定ファイルをホームディレクトリにリンク
3. **Brewパッケージ**: `~/.Brewfile`からすべてのパッケージをインストール
4. **gh拡張機能**: gh-dashをインストール
5. **launchd**: 自動更新ジョブを登録（平日09:30にclaude-code更新）

### オプション

```bash
# Homebrew関連の処理をスキップ（シンボリックリンクのみ作成）
./setup.sh --no-brew
```

### 3. ターミナルを再起動

設定を反映するためにターミナルを再起動してください。

## シンボリックリンク一覧

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
| `~/scripts/update-claude-code.sh` | `brew/scripts/update-claude-code.sh` |
| `~/Library/.../Code/User/settings.json` | `vscode/settings.json` |
| `~/Library/.../Code/User/keybindings.json` | `vscode/keybindings.json` |
| `~/Library/LaunchAgents/com.user.update-claude-code.plist` | `brew/scripts/com.user.update-claude-code.plist` |

## ディレクトリ構成

```
dotfiles/
├── brew/            # Homebrew Brewfile + 自動更新スクリプト
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
- **AI**: Claude Code（平日09:30に自動更新）
