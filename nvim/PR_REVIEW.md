# Neovim PR Review ワークフロー

## セットアップ

```bash
# gh-dashはGitHub CLI extension
gh extension install dlvhdr/gh-dash
```

## gh-dash からレビュー開始

```bash
# どこからでも実行可能（PRを選ぶと自動で該当リポジトリに移動）
gh dash
```

| キー | 動作 |
|------|------|
| `d` | diffview.nvimでdiff表示（tmux新窓） |
| `C` | Octo.nvimでPRレビュー画面（tmux新窓） |
| `o` | ブラウザでPR表示 |
| `m` | PRをsquash merge |
| `a` | PRをApprove |

## Neovim内キーバインド

### PR操作 (Octo.nvim)

| キー | 動作 |
|------|------|
| `<leader>gpl` | PR一覧表示 |
| `<leader>gpr` | レビュー開始 |
| `<leader>gps` | レビュー送信 |
| `<leader>gpm` | PRマージ (squash) |

### Diff表示 (diffview.nvim)

| キー | 動作 |
|------|------|
| `<leader>gdo` | Diffview開く |
| `<leader>gdc` | Diffview閉じる |
| `<leader>gdh` | 現在ファイルの履歴 |

## 典型的なワークフロー

### 1. gh-dashから開始
```bash
gh dash
# Review Requestsセクションでレビュー待ちPRを確認
# d キーでdiffview表示、または C キーでOcto画面
```

### 2. Neovim単体で開始
```vim
:Octo pr list
" PRを選択してEnter
:Octo review start
" コードを確認、コメント追加
:Octo review submit
```

### 3. diffviewでの差分確認
```vim
:DiffviewOpen origin/main...HEAD
" または特定コミット間
:DiffviewOpen HEAD~3
```

## Octo.nvim コマンド一覧

```vim
:Octo pr list           " PR一覧
:Octo pr checkout {num} " PRをcheckout
:Octo pr changes        " PR変更ファイル一覧
:Octo review start      " レビュー開始
:Octo review submit     " レビュー送信
:Octo review comments   " レビューコメント一覧
:Octo comment add       " コメント追加
:Octo pr merge squash   " squash merge
:Octo pr approve        " Approve
```

## トラブルシューティング

```bash
# gh認証確認
gh auth status

# GitHub CLI再認証
gh auth login
```
