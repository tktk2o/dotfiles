return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = { "markdown" },
  build = "cd app && npm install",
  keys = {
    { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview (Browser)" },
  },
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
    vim.g.mkdp_combine_preview = 0
    vim.g.mkdp_auto_close = 0
  end,
}
