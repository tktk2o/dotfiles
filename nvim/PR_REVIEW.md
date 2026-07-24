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
| `d` | `gh pr diff <n> -R <repo> \| delta --paging=always` をtmux新窓で表示（checkoutなし） |
| `R` | AIレビュー: tmux新窓を2分割し、左で `claude "/review <PR URL>"`、右で同じdiffを表示 |
| `o` | ブラウザでPR表示 |
| `m` | PRをsquash merge |
| `a` | PRをApprove |
| `y` | PR番号をコピー（gh-dash組み込み） |
| `Y` | PR URLをコピー（gh-dash組み込み） |

## Neovim内キーバインド

### Diff表示 (diffview.nvim, ローカルの差分確認用)

| キー | 動作 |
|------|------|
| `<leader>gdo` | Diffview開く |
| `<leader>gdc` | Diffview閉じる |
| `<leader>gdh` | 現在ファイルの履歴 |

## 典型的なワークフロー

### 1. gh-dashから差分だけ確認する
```bash
gh dash
# Review Requestsセクションでレビュー待ちPRを確認
# d キーでdiff表示（gh pr diff | delta、checkout不要）
```

### 2. gh-dashからAIレビューを依頼する
```bash
gh dash
# R キーでtmux新窓を分割し、左でclaude "/review <PR URL>"、右で同じdiffを表示
```

### 3. ローカルにチェックアウト済みのブランチをdiffviewで確認する
```vim
:DiffviewOpen origin/main...HEAD
" または特定コミット間
:DiffviewOpen HEAD~3
```

## トラブルシューティング

```bash
# gh認証確認
gh auth status

# GitHub CLI再認証
gh auth login
```
