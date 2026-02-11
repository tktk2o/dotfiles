return {
  "nvim-neo-tree/neo-tree.nvim",
  init = function()
    -- 起動時に Neo-tree を自動で開く
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        if vim.fn.argc() == 0 then
          -- 引数なしで起動した場合のみ開く
          vim.cmd("Neotree show")
        end
      end,
    })
  end,
  opts = function(_, opts)
    opts.close_if_last_window = true

    -- filesystem settings
    opts.filesystem = opts.filesystem or {}
    opts.filesystem.use_libuv_file_watcher = true
    opts.filesystem.filtered_items = vim.tbl_deep_extend("force",
      opts.filesystem.filtered_items or {},
      {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      }
    )

    -- window settings
    opts.window = opts.window or {}
    opts.window.width = 35
    opts.window.mappings = opts.window.mappings or {}
    -- Override Y to copy relative path instead of absolute
    opts.window.mappings["Y"] = {
      function(state)
        local node = state.tree:get_node()
        local path = node:get_id()
        local rel_path = vim.fn.fnamemodify(path, ":.")
        vim.fn.setreg("+", rel_path, "c")
        vim.notify("Copied: " .. rel_path)
      end,
      desc = "Copy Relative Path",
    }
  end,
}
