-- docs/ 横断検索（Telescope）
-- <leader>nd: ファイル名検索
-- <leader>ng: 全文grep検索

local docs_dir = vim.fn.expand("~/docs")

vim.keymap.set("n", "<leader>nd", function()
  require("telescope.builtin").find_files({ cwd = docs_dir, prompt_title = "Docs: Files" })
end, { desc = "Docs: find files" })

vim.keymap.set("n", "<leader>ng", function()
  require("telescope.builtin").live_grep({ cwd = docs_dir, prompt_title = "Docs: Grep" })
end, { desc = "Docs: grep" })

return {}
