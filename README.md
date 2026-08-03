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
9. **Finder連携**: `Open in Neovim.app`をビルドし、テキスト系拡張子を関連付けるか確認

### オプション

```bash
# Homebrew関連の処理をスキップ（シンボリックリンクのみ作成）
./setup.sh --no-brew

# macOSの既定アプリを変更する確認を出さない
./setup.sh --no-file-handlers
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
├── zsh/             # シェル設定 + plugins/
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
- **Finderから開く**: `nvim-open` — テキスト系ファイルをtmux新ウィンドウのnvimで開く（`macos/scripts/register-file-handlers.sh`で拡張子を登録）
- **過去セッション検索**: `csr` (`prefix + F`) — 過去の Claude Code セッションを自分の発言で全文検索して再開
- **AI**: Claude Code (+ rtk: Bash出力フィルタ)

## コマンド一覧

この dotfiles が提供するエイリアス・関数・キーバインド・実行ファイルは
[docs/cheatsheet.md](./docs/cheatsheet.md) にまとまっている（設定ファイルから自動生成）。
ターミナルからは `keys` で fzf 検索、`keys --doc`（tmux は `prefix + g`）で
そのまま読む、`keys --generate` で再生成。

## Finder / ブラウザから nvim で開く (`nvim-open`)

Finderでテキスト系ファイルをダブルクリックする、あるいはブラウザで落としたファイルを開くと、
**最後に使っていたtmuxセッションに新しいウィンドウが立ち上がってnvimで開く**。

### 配置

| 場所 | 中身 |
|------|------|
| `macos/nvim-open/main.swift` | 本体（ソース）。CLIと`.app`の実行ファイルを兼ねる |
| `macos/scripts/register-file-handlers.sh` | 拡張子を既定アプリに紐付ける／戻すスクリプト |
| `nvim-peek/init.lua` | 覗き見用の軽量Neovim設定 |
| `zsh/plugins/nvl.zsh` | `nvl`（Downloadsの最新ファイルを開く） |

`setup.sh`が作る生成物（いずれもシンボリックリンクではない）:

| 生成先 | 作られ方 |
|--------|---------|
| `~/.local/bin/nvim-open` | `swiftc`でビルド |
| `~/Applications/Open in Neovim.app` | 同じバイナリ + 生成した`Info.plist` |
| `~/.config/peek` | `nvim-peek/`へのシンボリックリンク（`NVIM_APPNAME=peek`が読む） |

### なぜこの形になったか

**なぜ`.app`が必要か** — macOSはファイルを`.app`バンドルにしか渡さない。CLIバイナリを
直接「既定のアプリ」に指定する方法は存在しない。

**なぜSwiftか（Goではなく）** — macOSはファイルパスを**argvではなくApple Event
(`kAEOpenDocuments`)で渡す**。argvを読むだけのバイナリをバンドルに入れて実測したところ
`argc=0`で、パスは一切届かなかった。受け取るにはAppKitのイベントループが必要で、Goだと
cgo + Objective-Cブリッジを書くことになる。このリポジトリの他のツール（`csr` / `keys`）は
Goだが、ここだけSwiftなのはこの制約のため。

**なぜAppleScriptをやめたか** — 最初はAppleScript appletがシェル経由で処理する実装だった。
`do shell script`のホップが**154ms ± 62**かかっていた。Swiftバイナリなら**4.5ms ± 0.7**で、
Apple Eventを受けたプロセスがそのまま処理するのでホップも1回で済む。

**なぜpeekプロファイルか** — 起動時間の残り半分はnvim自身だった。LazyVimは**137〜177ms**、
プラグインなしの設定なら**30ms**。「中身を確認する」用途にLSPやtreesitterは要らないので、
`NVIM_APPNAME=peek`で別設定にした。覗くだけのつもりが作業になったら`:Full`か`<leader>f`で
そのウィンドウを通常設定で開き直せる。`nvim-open --full`なら最初から通常設定。

結果、ダブルクリックからnvimが見えるまで**約360ms → 100ms未満**。

### 使い方 / 元に戻し方

```bash
# setup.sh の確認で見送った後、手動で拡張子を紐付ける
macos/scripts/register-file-handlers.sh

macos/scripts/register-file-handlers.sh --list     # 現在の紐付けを確認
macos/scripts/register-file-handlers.sh --revert   # TextEditに戻す

nvl        # Downloadsの最新ファイルを開く
nvl 3      # 新しい順に3件
```

開いたウィンドウには**ファイル名が付く**（複数選択時は`data.json +1`のように残り件数、
長い名前は20文字で切る）。`.tmux.conf`の`allow-rename off`はプログラムによる後からの
リネームを止めるだけで、作成時に付けた名前はそのまま残る。

紐付けるのはUTIではなく**拡張子**（txt, md, json, yaml, csv, log, ts, py, go, tf, sql,
css, swiftなど42種）。`public.plain-text`のようなUTIを奪うと影響範囲が広すぎるため。

- **html / htm / svg は意図的に除外** — レンダリングして見たいのでブラウザのまま。
  ソースを読みたいときは`nvim-open file.html`か、Finderの「このアプリケーションで開く」
- pdf・画像・zip・Office系も既定のまま（Quick Lookの方が速い）

新しいPCでは`swiftc`（Xcode Command Line Tools）と`duti`（Brewfileに含む）が必要。
`swiftc`が無い場合`setup.sh`は警告を出してビルドをスキップする。

> 開発運用上の詳細（gh-dashのキーバインド、ローカル管理ファイル、pre-commitリーク検査、rtkの健全性チェックなど）は [CLAUDE.md](./CLAUDE.md) を参照。
