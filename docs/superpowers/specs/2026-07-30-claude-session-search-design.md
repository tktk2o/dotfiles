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

**都度全抽出 + fzf 内で絞り込み。**

起動時に全 user 発言を 1 行 1 発言の TSV に落として fzf に流し、絞り込みは fzf の
ファジー検索に任せる。

検討して却下した案:

- **fzf の `change:reload` で rg を都度実行**: 抽出コストは払わないが、対象が生の
  JSON なので 1 行 = 1 JSON エントリになり、表示整形のために結局 jq が必要。
  マッチ位置と表示のズレも出るため旨みが薄い。
- **キャッシュインデックス**（`~/.cache/` に TSV、mtime 差分更新）: 2 回目以降は
  瞬時だが、キャッシュ無効化という可動部が増える。1.4 秒が待てなくなってから
  CLI の見た目を変えずに後付けできるので、今は入れない。

## インターフェース

```
csr [query]     fzf ピッカーを開く（query があれば --query に流して即絞り込み）
csr --here      cwd のプロジェクトのセッションだけに絞る
csr --list      候補を TSV で標準出力に印字して終了（fzf / tmux 不要）
csr --help      使い方
```

- 既定スコープは**全プロジェクト横断**。`--here` で絞る。
- `--list` は fzf も tmux も要らないため、動作確認の唯一の手段になる
  （`./setup.sh` を実行して確かめることは禁止されている。後述）。
- 環境変数 `CLAUDE_PROJECTS_DIR`（既定 `~/.claude/projects`）でログ置き場を
  差し替えられる。検証時に fixture ディレクトリを指すために使う。

## 候補行の作り方

`find "$CLAUDE_PROJECTS_DIR" -name '*.jsonl'` の各エントリを jq で処理し、
1 行 1 発言の TSV を生成する。

```
session_id \t cwd \t timestamp(ISO) \t 1行化した発言
```

### 抽出対象

`.type == "user"` のうち**人間が打った発言のみ**。次を除外する:

- `tool_result`（`.message.content` が配列で `type == "tool_result"` の要素）
- `<system-reminder>` / `<command-name>` / `<local-command-stdout>` で始まるテキスト
- 空文字列になったもの

`.message.content` は文字列の場合と配列の場合があるため、配列なら
`type == "text"` の要素だけを結合する。

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

- 表示列は `リポジトリ名  YYYY-MM-DD HH:MM  発言`。session_id と cwd のフルパスは
  `--with-nth` で列から隠す（検索対象からも外す）
- ソートは新しい順
- プレビュー: 選択行のセッションファイルから、その発言の**前後数ターン**を jq で
  切り出して表示。ヘッダに cwd フルパスと session_id を出す
- 引数の query は `--query` に流す

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
| `claude/scripts/claude-session-search.sh` | 本体（新規） |
| `setup.sh` | `~/.local/bin/csr` へのシンボリックリンクを `create_symlink` で追加 |
| `tmux/.tmux.conf` | `bind F` を追加 |
| `CLAUDE.md` | `csr` の説明とローカル依存（`~/.local/bin/csr` リンク）を追記 |

シェルスクリプトは repo の規約どおり `#!/bin/bash` + `set -e`。

## エラー処理

| 状況 | 挙動 |
|---|---|
| `jq` / `fzf` が無い | 起動時に不足しているコマンド名を出して exit 1（`--list` は fzf 不要なので jq のみ要求） |
| `CLAUDE_PROJECTS_DIR` が無い | 「セッションログが見つかりません」で exit 1 |
| 候補ゼロ（`--here` で絞った結果など） | メッセージを出して exit 0 |
| fzf をキャンセル（Esc / C-c） | 何もせず exit 0 |
| `claude --resume` 自体の失敗 | claude 側のメッセージに委ねる（wrap しない） |

## 検証方法

この repo には自動テスト基盤が無い（`twr` にも無い）ため、静的検査 + `--list` に
よる手動確認で担保する。

- `bash -n claude/scripts/claude-session-search.sh`（編集ごと）
- `shellcheck claude/scripts/claude-session-search.sh`
- `csr --list | head` で候補行の形を目視確認
- `CLAUDE_PROJECTS_DIR=<fixture> csr --list` で、除外ルール（tool_result /
  `<system-reminder>` / 空行）が効いていることを確認
- **`./setup.sh` は実行しない。** `create_symlink` が `rm -rf "$dest"` するため、
  このマシンの実ファイルを壊す。シンボリックリンク行はソースパスの存在確認と
  `ls -la` で足りる

## 非目標（YAGNI）

- 会話ビューア / ページャ（resume すれば読めるため不要）
- assistant 発言や tool 出力の検索（ノイズが多い。必要になったらフラグで足す）
- キャッシュインデックス（1.4 秒で足りているうちは入れない）
- セッションの削除・アーカイブ管理
