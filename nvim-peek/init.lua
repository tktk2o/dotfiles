-- Peek profile: the Neovim you get when you double-click a file in Finder or
-- open something you just downloaded.
--
-- Reached via NVIM_APPNAME=peek, so it is a wholly separate config from
-- nvim/ (LazyVim) and loads no plugin manager at all. That is the point:
-- measured 30ms here against ~150ms for the full config, and looking at a
-- file needs no LSP, completion or treesitter.
--
-- When a peek turns into real work, `:Full` reopens the file in the full setup.

vim.g.mapleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.cursorline = true
opt.signcolumn = "no" -- nothing here populates it
opt.wrap = false
opt.scrolloff = 4
opt.termguicolors = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- Read-mostly: keep the temp files out of the way rather than littering
-- alongside downloads.
opt.swapfile = false
opt.backup = false
opt.undofile = false

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2

-- Closest builtin to the Dracula used everywhere else, with no plugin cost.
pcall(vim.cmd.colorscheme, "habamax")

-- q quits when just looking; :q still works when it should not.
vim.keymap.set("n", "q", "<cmd>qa!<cr>", { desc = "Quit the peek" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Reopen the current file in the full config, in this same window.
vim.api.nvim_create_user_command("Full", function()
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("Full: no file in this buffer", vim.log.levels.WARN)
    return
  end
  -- exec replaces the peek rather than nesting an editor inside it.
  vim.cmd("silent! write")
  vim.fn.jobstart({ "tmux", "respawn-window", "-k", "-c", vim.fn.expand("%:p:h"), "nvim", file })
end, { desc = "Reopen this file with the full Neovim config" })

vim.keymap.set("n", "<leader>f", "<cmd>Full<cr>", { desc = "Reopen with the full config" })

-- A peek is usually a glance at structure: fold nothing, but show where you are.
vim.opt.laststatus = 2
vim.opt.statusline = "%f%m%r%=%l:%c  %P  [peek]"
