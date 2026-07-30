# csr — 過去の Claude Code セッションを文字列検索して resume する

作成日: 2026-07-30

## 目的

「あの作業、いつどのリポジトリで Claude に頼んだか」を思い出せないことがある。
`claude --resume` はカレントプロジェクトのセッション一覧しか出さないため、
プロジェクトを跨いだ発見ができない。

そこで、**過去の全セッションを自分の発言の文字列で横断検索し、選んだセッションを
そのまま resume する** CLI を追加する。

副次的に「どのプロジェクトでいつ話したか」が一覧で分かることも要件に含む
（一覧の表示情報として満たす。読み物としての会話ビューアは作らない）。

## 前提となる実測値

- セッションログ: `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`
- 規模: 434 セッション / 計 269MB
- 全ファイルから user 発言を抽出するコスト: **約 1.4 秒**（77,762 行 / 4.3MB）
  - この 77k 行には tool_result や hook 由来の行が混ざっており、人間の発言は
    さらに少ない

この規模なら事前インデックスなしで毎回抽出して fzf に流せる。

## 採用アプローチ

**Go の単一バイナリ + mtime 差分インデックスキャッシュ。** 絞り込みは fzf。

最初は shell + jq で書いたが **8.3 秒**かかった。前段に grep を入れて jq の入力を
1/5 に削っても改善せず、コストは入力量ではなく jq の正規表現側にあった。

そもそも `rg` で 269MB を舐めるだけで **90ms**（ページキャッシュ上）なので、
毎回全走査する設計では JSON パースを乗せた時点で 100ms は原理的に届かない。
よって「全部読まない」しかなく、差分キャッシュが必須になる。

実測結果:

| 実装 | 初回 | 2 回目以降 |
|---|---|---|
| shell + jq | 8.3s | 8.3s |
| shell + grep 前段 + jq | 8.3s | 8.3s |
| Go + 差分キャッシュ | 0.76s | **0.02〜0.03s** |

検討して却下した案:

- **fzf の `change:reload` で rg を都度実行**: 対象が生の JSON なので 1 行 = 1
  エントリになり、表示整形のために結局パースが必要。マッチ位置と表示のズレも出る。
- **Rust**: このマシンに cargo/rustc が入っておらず、Go 1.26 は入っている。
  性能要件は Go で満たせるので、ツールチェーンを増やす理由がない。
- **キャッシュなしの Go 全走査**: 初回相当の 0.76s が毎回かかる。要件に届かない。

## インターフェース

```
csr [query]     fzf ピッカーを開く（query があれば --query に流して即絞り込み）
csr --here      cwd のプロジェクトのセッションだけに絞る
csr --list      候補を TSV で標準出力に印字して終了（fzf / tmux 不要）
csr --help      使い方
```

- 既定スコープは**全プロジェクト横断**。`--here` で絞る。
- `--list` は fzf も tmux も要らないため、動作確認の主な手段になる
  （`./setup.sh` を実行して確かめることは禁止されている。後述）。
- 環境変数で差し替え可能: `CLAUDE_PROJECTS_DIR`（既定 `~/.claude/projects`）、
  `CSR_CACHE_DIR`（既定 `~/.cache/csr`）。後者は計測時にキャッシュ無し状態を
  作るために使う（`rm -rf` で本物のキャッシュを消さずに済む）。
- `--preview FILE TIMESTAMP` は内部用。fzf が各行に対して自分自身を呼ぶ。

## キャッシュ

`~/.cache/csr/` に 2 ファイル持つ。

- `manifest.tsv`: フォーマット版 + `path \t mtime(ns) \t size`
- `index.tsv`: 抽出済みレコード（`file \t sid \t cwd \t ts \t when \t text`）

実行時に全 jsonl を stat し、size と mtime が一致するものはキャッシュのレコードを
再利用、変わったものだけワーカプールで再パースする。日常的に変わるのは「今いる
セッション」1 本なので、定常状態は実質「小さな TSV を読むだけ」になる。

- 書き込みは temp + rename。index → manifest の順に書く（レコードの無い manifest
  はサーブできないヒットを主張してしまう）。
- キャッシュが壊れていたり無い場合は「全部変更あり」として扱う。純粋な派生データ
  なので、消しても遅い実行 1 回分のコストしかない。
- キャッシュには**絞り込み前の全件**を入れる。`--here` の結果でキャッシュを
  汚さないため、フィルタは最後に掛ける。

## 候補行の作り方

`CLAUDE_PROJECTS_DIR` 以下の `*.jsonl` を走査し、1 レコード = 1 発言にする。

```
file \t session_id \t cwd \t timestamp \t local_time \t text
```

session_id はファイルのベース名（`claude --resume` が取る値そのもの）。

### 抽出対象

`.type == "user"` のうち**人間が打った発言のみ**。次を除外する:

- `tool_result`（`.message.content` の配列要素のうち `type == "text"` 以外）
- `.isMeta` が立っているエントリ
- ハーネスが user ロールに差し込むブロックで始まるテキスト:
  `<system-reminder>` `<command-name>` `<command-message>` `<command-args>`
  `<local-command-stdout>` `<local-command-stderr>` `<user-prompt-submit-hook>`
  `<bash-input>` `<bash-stdout>` `<bash-stderr>`
- 空文字列になったもの

`.message.content` は文字列の場合と配列の場合があるため、配列なら
`type == "text"` の要素だけを結合する。

実測で 77,762 の user エントリが **1,885 件の実発言**に落ちる。JSON デコードの前に
`"type":"user"` のバイト列で弾く安価な前段フィルタを掛ける。

セッションログには 1 行が巨大な行（貼り付けたファイル、大きな tool 結果）が
あるため、行バッファ上限を 32MB まで引き上げる。書きかけの最終行で走査全体を
落とさない。

### プロジェクト名の決定

**ディレクトリ名からデコードしない。** `~/.claude/projects/` のディレクトリ名は
パス区切りとハイフンを同じ `-` に潰しているため、元のパスを一意に復元できない
（`src/github.com/<org>/<a-b>` と `src/github.com/<org>/<a>/<b>` が同名になる）。

代わりに jsonl エントリが持つ `cwd` フィールドをそのまま使う。これが表示名の
ソースであり、resume 時の `cd` 先も兼ねる。

### 整形

- 改行はスペースに畳む
- 表示は先頭 200 字で切る（全文はプレビューで見せる）

## fzf の見せ方

- 表示列（5 列目）は `リポジトリ名  YYYY-MM-DD HH:MM  発言`。1〜4 列目（file /
  session_id / cwd / timestamp）は `--with-nth=5` で隠す（検索対象からも外れる）
- ソートは新しい順（`--no-sort` で fzf 側の並べ替えを止める）
- プレビュー: 選択行のセッションから、その発言の**前後 3 ターン**を表示。
  マッチ行に `▶` を付ける
- 引数の query は `--query` に流す
- fzf のキャンセル（Esc / C-c）は非ゼロ終了だが、これは失敗ではないので黙って終わる

## Enter したときの挙動

1. **tmux 内**: `tmux new-window -c <cwd> "claude --resume <id>"`
   今の作業ペインを潰さない。`twr`（`prefix + W`）と同じ思想。
2. **tmux 外**: `cd <cwd> && exec claude --resume <id>`
3. **cwd が既に存在しない**（リポジトリを消した等）: 警告を出して `$HOME` で起動

## tmux 統合

`tmux/.tmux.conf` に popup 起動を追加する。

```tmux
bind F display-popup -E -w 80% -h 70% "$HOME/.local/bin/csr"
```

キー選定の根拠:

- tmux デフォルトで埋まっているのは小文字 `s`（`choose-tree -Zs`）と `w`。
  大文字 `S` / `W` は未割り当て（既存の `twr` = `prefix + W` が衝突しないのも同じ理由）
- 大文字 `C` は `customize-mode` で埋まっているため使えない
- `S` は空いているが、小文字 `s` が「tmux セッションを選ぶ」なので、隣の `S` が
  「Claude のセッションを選ぶ」だと意味が混線する。押し間違えたときどちらも
  「セッション一覧」が出るのは分かりにくい
- よって `F`（find past claude session）を採る

## ファイル構成

| ファイル | 役割 |
|---|---|
| `claude/csr/main.go` | CLI・fzf 起動・プレビュー・resume |
| `claude/csr/extract.go` | jsonl 1 本から発言/会話ターンを取り出す |
| `claude/csr/cache.go` | 差分インデックスの読み書き |
| `claude/csr/scan.go` | 走査・キャッシュ判定・並列パース・並べ替え |
| `claude/csr/exec_unix.go` | `syscall.Exec`（tmux 外での置き換え起動） |
| `setup.sh` | `setup_csr`: `go build -o ~/.local/bin/csr` |
| `tmux/.tmux.conf` | `bind F` を追加 |
| `brew/.Brewfile` | `brew "go"`（ビルドに必要） |
| `CLAUDE.md` | `csr` の説明と新マシン手順を追記 |

`twr` と違いシンボリックリンクではなく**ビルド成果物**を置くので、`setup.sh` の
`create_symlink` は通さない。go が無いマシンではスキップして警告を出す。

## エラー処理

| 状況 | 挙動 |
|---|---|
| `go` が無い（setup 時） | ビルドをスキップして理由を表示 |
| `fzf` が無い | fzf 起動失敗をそのままエラーとして返す（`--list` は fzf 不要） |
| `CLAUDE_PROJECTS_DIR` が無い | 走査エラーを表示して exit 1 |
| 候補ゼロ（`--here` で絞った結果など） | `--here` を外す誘導を出して exit 1 |
| fzf をキャンセル（Esc / C-c） | 何もせず exit 0 |
| キャッシュが壊れている / 書けない | 黙って全件パースにフォールバック（速度だけの損失） |
| 読めない jsonl / 壊れた行 | その行・その1本を飛ばし、検索全体は続行 |
| `claude --resume` 自体の失敗 | claude 側のメッセージに委ねる（wrap しない） |

## 検証方法

この repo には自動テスト基盤が無い（`twr` にも無い）ため、Go の標準チェックと
`--list` による実データ確認で担保する。

- `gofmt -l claude/csr` が何も出さないこと
- `go vet ./...` / `go build`
- `csr --list | head` で候補行の形を目視確認
- `CSR_CACHE_DIR=<temp> csr --list` を 2 回走らせ、初回 < 1s・2 回目 < 100ms を確認
- shell 実装との出力差分を突き合わせ、消えた行が `<bash-input>` / `<bash-stdout>`
  だけであることを確認済み（意図した除外）
- `bash -n setup.sh`
- **`./setup.sh` は実行しない。** `create_symlink` が `rm -rf "$dest"` するため、
  このマシンの実ファイルを壊す

## 非目標（YAGNI）

- 会話ビューア / ページャ（resume すれば読めるため不要）
- assistant 発言や tool 出力の検索（ノイズが多い。必要になったらフラグで足す）
- セッションの削除・アーカイブ管理
- キャッシュのバックグラウンド更新やウォームアップ（0.76s の初回を 1 度だけ払えば
  済む話で、常駐プロセスを増やす価値がない）
