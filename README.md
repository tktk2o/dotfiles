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

1. **Homebrew**: 未インストールの場合、インストールを提案（見送ってもシンボリックリンク作成は継続）
2. **シンボリックリンク**: 設定ファイルをホームディレクトリにリンク（既存の実ファイルは
   削除されるので、初回以外は `--dry-run` で確認してから）
3. **Brewパッケージ**: `~/.Brewfile`からすべてのパッケージをインストール
4. **git hooks**: このリポジトリ用に `core.hooksPath` を設定（pre-commitリーク検査）
5. **sheldon**: zshプラグインのキャッシュを生成
6. **tmuxプラグイン**: TPM（tmux plugin manager）を導入
7. **gh拡張機能**: gh-dashをインストール
8. **rtk**: Claude Code用のBash出力フィルタを初期化
9. **Finder連携**: `Open in Neovim.app`をビルドし、テキスト系拡張子を関連付けるか確認

### オプション

```bash
# 何が起きるか表示するだけ。ファイルの作成/削除・インストール・対話プロンプトを
# 一切行わないので、既に設定済みのマシンでも安全に実行できる
./setup.sh --dry-run          # -n でも同じ

# Homebrew関連の処理をスキップ（シンボリックリンクのみ作成）
./setup.sh --no-brew

# macOSの既定アプリを変更する確認を出さない
./setup.sh --no-file-handlers
```

`--dry-run` は各リンク先を3状態に分けて表示する:

- 既に正しいリンク → `ok (already linked)`（何もしない）
- 別の場所を指すリンク → 貼り替える旨
- **実ファイル / 実ディレクトリ → `!! WOULD DELETE`**

`create_symlink` はリンク前に `rm -rf` するため、3番目は実行すると失われる。
設定済みのマシンで変更を確かめたいときは、素の `./setup.sh` ではなく必ず
`--dry-run` を使う。

### 3. ターミナルを再起動

設定を反映するためにターミナルを再起動してください。

### 4. ローカル管理ファイルの再作成（重要）

以下はこのリポジトリに含まれない（untracked）ため、新しいPCでは手動で用意します:

| ファイル | 用途 | 再作成方法 |
|---------|------|-----------|
| `gh-dash/config.local.yml` | gh-dashの実設定（会社固有のリポ名を含む） | `setup.sh`が`gh-dash/config.yml.example`から自動生成。会社固有の`prSections`を追記 |
| `~/.config/git/denylist.txt` | pre-commitリーク検査の会社固有ワード（1行1正規表現） | 手動で作成。無い場合は汎用シークレット検査のみ動作 |
| `~/.claude/RTK.md` | Claude Codeが読むrtkのグローバル指示 | `rtk init -g`で導入 |
| `~/.claude/local.md` + `~/.claude/local/*.md` | マシン固有のClaude指示。`local.md`は各トピック数行の薄いハブ（常時import）、詳細は`local/*.md`に置いてimportしない（必要なときだけ読む） | 手動で作成。社内の名称を含むためpublicなこのリポジトリには入れない |
| `~/.claude/settings.local.json` | マシン固有のClaude設定（追加の`permissions`、`deny`、会社プラグイン/マーケットプレイス） | 手動で作成。Claude Codeも権限付与時に書き込む。symlinkしない（追跡側は`claude/settings.json`） |

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
| `~/.config/peek` | `nvim-peek/`（Finderから開く用の軽量プロファイル） |
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
| `~/.claude/persona-github.md` | `claude/persona-github.md`（gh のコメント文体） |
| `~/.claude/rules` | `claude/rules/`（必要なときだけ読む方針ドキュメント。importしない） |

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
├── macos/           # Finder連携 (nvim-open / 既定アプリ登録)
├── mise/            # ランタイムバージョン管理
├── nvim/            # Neovim (LazyVim) 設定
├── nvim-peek/       # 覗き見用の軽量Neovim設定 (NVIM_APPNAME=peek)
├── raycast/         # Raycastスクリプト
├── sheldon/         # zshプラグインマネージャ
├── starship/        # シェルプロンプト
├── tmux/            # ターミナルマルチプレクサ + scripts/ (twr)
├── tools/           # cheatsheet/ (keys のソース)
├── tests/           # 不変条件テスト (run.sh)
├── docs/            # cheatsheet.md（自動生成）
├── zsh/             # シェル設定 + plugins/
├── treefmt.toml     # フォーマッタ登録 (shfmt / stylua / gofmt)
└── setup.sh         # セットアップスクリプト
```

## 主要ツール

- **シェル**: zsh + sheldon (プラグイン管理) + starship (プロンプト)
- **ターミナル**: Ghostty
- **エディタ**: Neovim (LazyVim)
- **マルチプレクサ**: tmux (prefix: Ctrl+B) + tmux-resurrect/continuum (セッション永続化: 自動保存のみ、復元は手動 `prefix + Ctrl-r` / `prefix + W`)
- **キーボード**: Karabiner-Elements
- **PRレビュー**: gh-dash + Neovim (diffview.nvim)
- **プロジェクト移動**: ghq + fzf (`fgh`)
- **過去ウィンドウ復元**: `twr` (`prefix + W`)
- **Finderから開く**: [`nvim-open`](./macos/nvim-open/README.md) — テキスト系ファイルをtmux新ウィンドウのnvimで開く
- **過去セッション検索**: `csr` (`prefix + F`) — 過去の Claude Code セッションを自分の発言で全文検索して再開
- **履歴の棚卸し**: `analyze`（使用頻度）/ `analyze --unused`（定義したのに使っていないもの）
- **起動時間計測**: `zshtime`（現状 平均96ms）/ `zshtime --profile` で内訳
- **AI**: Claude Code (+ rtk: Bash出力フィルタ)

## 変更を検証する

```bash
./setup.sh --dry-run                    # setup.sh の変更を副作用なしで確認
bash tests/run.sh                       # 不変条件テスト
bash -n setup.sh                        # シェル構文チェック
treefmt --no-cache --fail-on-change     # 整形漏れの確認（付けずに実行すると整形する）
```

`tests/` は**黙って壊れるもの**だけをテストする — 壊れた `create_symlink` の参照元、
解決されない `@` import、消えた `rtk hook claude`、意図的に revert した
`caffeinate` ラッパーの再導入、そして `claude/hooks/guard-dotfiles.sh` の
ガード対象と `setup.sh` のリンク一覧のズレ。いずれも失敗した時点では何も
エラーにならず、気づくのは壊れた後になる。`git/hooks/pre-commit` の layer 4
としてコミットを**ブロック**する。

`treefmt` は `setup.sh` にも pre-commit にも組み込んでいない（無関係な
コミットに巨大な整形差分が混ざるのを避けるため、実行は任意）。

Claude Code 側は `claude/hooks/guard-dotfiles.sh` が `PreToolUse` で
`--dry-run` なしの `./setup.sh` と、symlink 実体への直接書き込みを拒否する。

## コマンド一覧

この dotfiles が提供するエイリアス・関数・キーバインド・実行ファイルは
[docs/cheatsheet.md](./docs/cheatsheet.md) にまとまっている（設定ファイルから自動生成）。
ターミナルからは `keys` で fzf 検索、`keys --doc`（tmux は `prefix + g`）で
そのまま読む、`keys --generate` で再生成。

> 開発運用上の詳細（gh-dashのキーバインド、ローカル管理ファイル、pre-commitリーク検査、rtkの健全性チェックなど）は [CLAUDE.md](./CLAUDE.md) を参照。
