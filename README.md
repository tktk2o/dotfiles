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
4. **git hooks**: このリポジトリ用に `core.hooksPath` を設定（pre-commitリーク検査）
5. **sheldon**: zshプラグインのキャッシュを生成
6. **tmuxプラグイン**: TPM（tmux plugin manager）を導入
7. **gh拡張機能**: gh-dashをインストール
8. **rtk**: Claude Code用のBash出力フィルタを初期化

### オプション

```bash
# Homebrew関連の処理をスキップ（シンボリックリンクのみ作成）
./setup.sh --no-brew
```

### 3. ターミナルを再起動

設定を反映するためにターミナルを再起動してください。

### 4. ローカル管理ファイルの再作成（重要）

以下はこのリポジトリに含まれない（untracked）ため、新しいPCでは手動で用意します:

| ファイル | 用途 | 再作成方法 |
|---------|------|-----------|
| `gh-dash/config.local.yml` | gh-dashの実設定（会社固有のリポ名を含む） | `setup.sh`が`gh-dash/config.yml.example`から自動生成。会社固有の`prSections`を追記 |
| `~/.config/git/denylist.txt` | pre-commitリーク検査の会社固有ワード（1行1正規表現） | 手動で作成。無い場合は汎用シークレット検査のみ動作 |
| `~/.claude/RTK.md` | Claude Codeが読むrtkのグローバル指示 | `rtk init -g`で導入 |

また、rtkのプロジェクトフィルタは1台につき1回信頼登録が必要です:

```bash
cd ~/src/github.com/tktk2o/dotfiles && rtk trust
```

### 5. Native install するアプリ

以下はBrewfileで管理せず、公式サイト/コマンドでインストールします:

- Claude Code CLI: `curl -fsSL https://claude.ai/install.sh | bash`
- [Ghostty](https://ghostty.org/download)
- [Raycast](https://www.raycast.com/)
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/)
- [Figma](https://www.figma.com/downloads/)
- [Rancher Desktop](https://rancherdesktop.io/)

## シンボリックリンク一覧

| リンク先 | ソース |
|---------|--------|
| `~/.zshrc` | `zsh/.zshrc` |
| `~/.tmux.conf` | `tmux/.tmux.conf` |
| `~/.gitconfig` | `git/.gitconfig` |
| `~/.gitignore_global` | `git/.gitignore_global` |
| `~/.Brewfile` | `brew/.Brewfile` |
| `~/.config/zsh/plugins` | `zsh/plugins/` |
| `~/.config/nvim` | `nvim/` |
| `~/.config/ghostty/config` | `ghostty/config` |
| `~/.config/starship.toml` | `starship/starship.toml` |
| `~/.config/sheldon/plugins.toml` | `sheldon/plugins.toml` |
| `~/.config/mise/config.toml` | `mise/config.toml` |
| `~/.config/karabiner/karabiner.json` | `karabiner/karabiner.json` |
| `~/.config/gh/config.yml` | `gh/config.yml` |
| `~/.config/gh-dash/config.yml` | `gh-dash/config.local.yml`（untracked。`gh-dash/config.yml.example`から生成） |
| `~/.config/herdr/config.toml` | `herdr/config.toml` |
| `~/.local/bin/twr` | `tmux/scripts/tmux-window-restore.sh` |
| `~/.claude/CLAUDE.md` | `claude/CLAUDE.md` |
| `~/.claude/settings.json` | `claude/settings.json` |
| `~/.claude/statusline-command.sh` | `claude/statusline-command.sh` |
| `~/.claude/hooks` | `claude/hooks/` |
| `~/.claude/skills` | `claude/skills/` |
| `~/.claude/worktree.md` | `claude/worktree.md` |
| `~/.claude/model-policy.md` | `claude/model-policy.md` |
| `~/Library/.../Code/User/settings.json` | `vscode/settings.json` |
| `~/Library/.../Code/User/keybindings.json` | `vscode/keybindings.json` |

## ディレクトリ構成

```
dotfiles/
├── brew/            # Homebrew Brewfile
├── claude/          # Claude Code設定 (CLAUDE.md, settings, hooks, skills, statusline)
├── gh/              # GitHub CLI設定
├── gh-dash/         # gh-dash設定 (config.yml.example / config.local.yml)
├── ghostty/         # ターミナルエミュレータ設定
├── git/             # Git設定 + hooks
├── herdr/           # herdr設定
├── karabiner/       # キーボードカスタマイズ
├── mise/            # ランタイムバージョン管理
├── nvim/            # Neovim (LazyVim) 設定
├── raycast/         # Raycastスクリプト
├── sheldon/         # zshプラグインマネージャ
├── starship/        # シェルプロンプト
├── tmux/            # ターミナルマルチプレクサ + scripts/ (twr)
├── vscode/          # VSCode設定
├── zsh/             # シェル設定 + plugins/
└── setup.sh         # セットアップスクリプト
```

## 主要ツール

- **シェル**: zsh + sheldon (プラグイン管理) + starship (プロンプト)
- **ターミナル**: Ghostty
- **エディタ**: Neovim (LazyVim) / VSCode
- **マルチプレクサ**: tmux (prefix: Ctrl+B) + tmux-resurrect/continuum (セッション永続化)
- **キーボード**: Karabiner-Elements
- **PRレビュー**: gh-dash + Neovim (diffview.nvim)
- **プロジェクト移動**: ghq + fzf (`fgh`)
- **過去ウィンドウ復元**: `twr` (`prefix + W`)
- **AI**: Claude Code (+ rtk: Bash出力フィルタ)

> 開発運用上の詳細（gh-dashのキーバインド、ローカル管理ファイル、pre-commitリーク検査、rtkの健全性チェックなど）は [CLAUDE.md](./CLAUDE.md) を参照。
