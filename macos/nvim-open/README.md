# nvim-open

Finderでテキスト系ファイルをダブルクリックする、あるいはブラウザで落としたファイルを開くと、
**最後に使っていたtmuxセッションに新しいウィンドウが立ち上がってnvimで開く**。

## 配置

| 場所 | 中身 |
|------|------|
| [`main.swift`](./main.swift) | 本体（ソース）。CLIと`.app`の実行ファイルを兼ねる |
| [`../scripts/register-file-handlers.sh`](../scripts/register-file-handlers.sh) | 拡張子を既定アプリに紐付ける／戻すスクリプト |
| [`../../nvim-peek/init.lua`](../../nvim-peek/init.lua) | 覗き見用の軽量Neovim設定 |
| [`../../zsh/plugins/nvl.zsh`](../../zsh/plugins/nvl.zsh) | `nvl`（Downloadsの最新ファイルを開く） |

[`setup.sh`](../../setup.sh)が作る生成物（いずれもシンボリックリンクではない）:

| 生成先 | 作られ方 |
|--------|---------|
| `~/.local/bin/nvim-open` | `swiftc`でビルド |
| `~/Applications/Open in Neovim.app` | 同じバイナリ + 生成した`Info.plist` |
| `~/.config/peek` | `nvim-peek/`へのシンボリックリンク（`NVIM_APPNAME=peek`が読む） |

## なぜこの形になったか

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

## 使い方 / 元に戻し方

リポジトリルートから実行する。

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

新しいPCでは`swiftc`（Xcode Command Line Tools）と`duti`（[`Brewfile`](../../brew/.Brewfile)に含む）が必要。
`swiftc`が無い場合`setup.sh`は警告を出してビルドをスキップする。
