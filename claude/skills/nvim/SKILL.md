---
name: nvim
description: >
  Neovim/LazyVim configuration assistant.
  Use when: adding/editing plugins in nvim/lua/plugins/,
  modifying keymaps or options, troubleshooting LazyVim config.
allowed-tools: Read, Edit, Write, Glob, Grep, WebSearch, WebFetch
---

# Neovim/LazyVim Configuration Assistant

## 現在のプラグイン一覧
!`ls nvim/lua/plugins/`

## 必須ルール

- プラグイン追加は `nvim/lua/plugins/<name>.lua` に1ファイル1プラグイン
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

詳細なキーマップ一覧、Extras設定、トラブルシューティングは
[LAZYVIM_REFERENCE.md](../../nvim/LAZYVIM_REFERENCE.md) を参照。
