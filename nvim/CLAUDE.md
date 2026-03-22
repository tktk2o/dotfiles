# Neovim/LazyVim Configuration Rules

## 必須ルール

- プラグイン追加は `lua/plugins/<name>.lua` に1ファイル1プラグイン
- フォーマット: `return { "author/plugin", opts = {} }`
- `lazy = false` は明示的に必要な場合のみ（smart-splits等）
- キーマップは `keys = {}` で遅延読み込みを優先
- カラースキームは Dracula で統一

## プラグイン追加テンプレート

```lua
return {
  "author/plugin-name",
  keys = {
    { "<leader>xx", "<cmd>Command<cr>", desc = "Description" },
  },
  opts = {},
}
```

## 参照ドキュメント

- [LAZYVIM_REFERENCE.md](./LAZYVIM_REFERENCE.md) - ディレクトリ構造、キーマップ一覧、Extras設定、トラブルシューティング
- [PR_REVIEW.md](./PR_REVIEW.md) - gh-dash + Neovim PRレビューワークフロー
