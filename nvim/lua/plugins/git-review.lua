return {
  -- Octo.nvim: GitHub PR操作
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    keys = {
      { "<leader>gpl", "<cmd>Octo pr list<cr>", desc = "List PRs" },
      { "<leader>gpr", "<cmd>Octo review start<cr>", desc = "Start Review" },
      { "<leader>gps", "<cmd>Octo review submit<cr>", desc = "Submit Review" },
      { "<leader>gpm", "<cmd>Octo pr merge squash<cr>", desc = "Merge PR (squash)" },
    },
    opts = {
      enable_builtin = true,
      default_remote = { "upstream", "origin" },
      picker = "telescope",
      suppress_missing_scope = {
        projects_v2 = true,
      },
    },
  },

  -- diffview.nvim: 差分表示
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
      { "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
      { "<leader>gdh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
    },
    opts = {
      enhanced_diff_hl = true,
      file_panel = {
        win_config = {
          position = "left",
          width = 35,
        },
      },
    },
  },
}
