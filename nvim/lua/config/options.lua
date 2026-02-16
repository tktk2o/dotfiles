-- Options are automatically loaded before lazy.nvim startup
-- Default options: https://www.lazyvim.org/configuration/general

local opt = vim.opt

-- インデント（LazyVimデフォルトは2）
opt.tabstop = 2
opt.shiftwidth = 2

-- Markdown: リスト継続時のインデントズレを修正
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.smartindent = false
  end,
})

-- プロジェクトローカル設定を有効化 (.nvim.lua)
opt.exrc = true

-- 外部変更の自動検知（Claude Code連携用）
vim.opt.autoread = true

-- BufEnterでもchecktime（LazyVimはFocusGainedのみ）
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if vim.bo.buftype == "" then
      vim.cmd("checktime")
    end
  end,
})

-- VSCode風: フォーカスを失ったら自動保存
vim.api.nvim_create_autocmd({ "FocusLost" }, {
  callback = function()
    vim.cmd("silent! wa")
  end,
})
