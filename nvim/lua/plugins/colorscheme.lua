return {
  -- Draculaテーマを追加
  { "Mofiqul/dracula.nvim" },

  -- LazyVimのデフォルトテーマをDraculaに変更
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dracula",
    },
  },
}
