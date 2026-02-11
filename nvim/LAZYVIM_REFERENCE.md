# LazyVim Reference

このファイルはClaude Codeがnvim設定を編集する際の参照用ドキュメントです。

## LazyVim ディレクトリ構造

```
~/.config/nvim/
├── init.lua                 # require("config.lazy") のみ
├── lua/
│   ├── config/
│   │   ├── lazy.lua         # lazy.nvim bootstrap + LazyVim setup
│   │   ├── options.lua      # vim.opt (LazyVimより先に読み込まれる)
│   │   ├── keymaps.lua      # キーマップ (VeryLazy event後)
│   │   └── autocmds.lua     # 自動コマンド (VeryLazy event後)
│   └── plugins/
│       └── *.lua            # プラグイン設定（自動読み込み）
└── lazy-lock.json           # バージョンロックファイル
```

## プラグイン追加パターン

### 基本形
```lua
return {
  "author/plugin-name",
}
```

### オプション付き
```lua
return {
  "author/plugin-name",
  opts = {
    setting = "value",
  },
}
```

### キーマップ付き（遅延読み込み）
```lua
return {
  "author/plugin-name",
  keys = {
    { "<leader>xx", "<cmd>PluginCommand<cr>", desc = "Description" },
  },
  opts = {},
}
```

### コマンド/イベントで遅延読み込み
```lua
return {
  "author/plugin-name",
  cmd = { "Command1", "Command2" },  -- コマンド実行時に読み込み
  event = "BufReadPre",              -- イベント発生時に読み込み
  opts = {},
}
```

### 依存関係付き
```lua
return {
  "author/plugin-name",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {},
}
```

### LazyVimプラグインのオーバーライド
```lua
return {
  "LazyVim/LazyVim",  -- または上書きしたいプラグイン名
  opts = {
    colorscheme = "dracula",
  },
}
```

## LazyVim Extras（有効化済み）

`lua/config/lazy.lua` で有効化:
- `lazyvim.plugins.extras.editor.neo-tree` - ファイラー
- `lazyvim.plugins.extras.lang.python`
- `lazyvim.plugins.extras.lang.typescript`
- `lazyvim.plugins.extras.lang.json`
- `lazyvim.plugins.extras.lang.yaml`

### 重要: Extras とデフォルトマッピング

**Extras を有効化しないとそのプラグインのデフォルトマッピングが設定されない。**

例: `neo-tree` extras を有効化しないと `Y`（パスコピー）、`O`（システムアプリで開く）などのマッピングが使えない。

### Extras追加方法
```lua
-- lua/config/lazy.lua の spec に追加
{ import = "lazyvim.plugins.extras.lang.rust" },
{ import = "lazyvim.plugins.extras.editor.mini-files" },
```

### Extras のマッピングをオーバーライドする方法

`lua/plugins/` で `opts` 関数を使う:
```lua
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.window = opts.window or {}
    opts.window.mappings = opts.window.mappings or {}
    opts.window.mappings["Y"] = {
      function(state)
        -- カスタム処理
      end,
      desc = "Description",
    }
  end,
}
```

主なExtras一覧: https://www.lazyvim.org/extras

## LazyVim デフォルトキーマップ

### 基本
| キー | 説明 |
|------|------|
| `<Space>` | Leader key |
| `<leader>e` | Neo-tree toggle |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>:` | Command history |

### Git (built-in)
| キー | 説明 |
|------|------|
| `<leader>gg` | Lazygit |
| `<leader>gf` | Git files |
| `<leader>gc` | Git commits |
| `<leader>gs` | Git status |

### LSP
| キー | 説明 |
|------|------|
| `gd` | Go to definition |
| `gr` | References |
| `K` | Hover doc |
| `<leader>ca` | Code action |
| `<leader>cr` | Rename |

### Window/Buffer
| キー | 説明 |
|------|------|
| `<C-h/j/k/l>` | Window移動 |
| `<S-h>` / `<S-l>` | 前/次のバッファ |
| `<leader>bd` | バッファ削除 |

## インストール済みプラグインのコマンド

### octo.nvim (GitHub PR)

| キーマップ | コマンド | 説明 |
|-----------|---------|------|
| `<leader>gpl` | `:Octo pr list` | PR一覧 |
| `<leader>gpr` | `:Octo review start` | レビュー開始 |
| `<leader>gps` | `:Octo review submit` | レビュー提出 |
| `<leader>gpm` | `:Octo pr merge squash` | PRマージ |

**その他のOctoコマンド:**
- `:Octo pr create` - PR作成
- `:Octo pr checkout {number}` - PRをチェックアウト
- `:Octo pr close` - PRクローズ
- `:Octo comment add` - コメント追加（レビュー中）
- `:Octo review comments` - レビューコメント一覧

### diffview.nvim (差分表示)

| キーマップ | コマンド | 説明 |
|-----------|---------|------|
| `<leader>gdo` | `:DiffviewOpen` | 差分ビュー開く |
| `<leader>gdc` | `:DiffviewClose` | 差分ビュー閉じる |
| `<leader>gdh` | `:DiffviewFileHistory %` | 現在ファイルの履歴 |

**その他のDiffviewコマンド:**
- `:DiffviewOpen origin/main...HEAD` - ブランチ間の差分
- `:DiffviewFileHistory` - リポジトリ全体の履歴
- `:DiffviewToggleFiles` - ファイルパネル切り替え

### neo-tree.nvim (ファイラー)

| キー | 説明 |
|------|------|
| `<leader>e` | Neo-tree toggle (LazyVimデフォルト) |
| `<leader>fe` | Neo-tree (Root Dir) |
| `<leader>fE` | Neo-tree (cwd) |
| `a` | 新規ファイル/フォルダ作成 |
| `d` | 削除 |
| `r` | リネーム |
| `Y` | **相対パス**をクリップボードにコピー（カスタム設定） |
| `O` | システムアプリで開く |
| `P` | プレビュー切替 |
| `H` | 隠しファイル表示切替 |
| `?` | ヘルプ（マッピング一覧） |

## このリポジトリの設定

### カスタムオプション (`lua/config/options.lua`)
- `tabstop = 2`
- `shiftwidth = 2`

### カラースキーム
- Dracula (`lua/plugins/colorscheme.lua`)

### neo-tree設定
- 隠しファイル表示: 有効
- gitignoreファイル表示: 有効
- パネル幅: 35
- `Y` で相対パスコピー（LazyVimデフォルトは絶対パス）

## トラブルシューティング

### 設定が反映されない場合

1. **ファイルが読み込まれているか確認**: 設定ファイルの先頭に `error("test")` を追加して再起動。エラーが出れば読み込まれている
2. **Extras が有効化されているか確認**: プラグインによっては extras を有効化しないとデフォルトマッピングが設定されない
3. **キャッシュクリア**: `:Lazy sync` または `~/.local/share/nvim/lazy/` を削除
4. **マッピング競合確認**: `:verbose nmap <key>` で確認（ただしNeo-tree内マッピングは表示されない）
5. **Neo-tree内のマッピング確認**: Neo-tree上で `?` を押してヘルプ表示
