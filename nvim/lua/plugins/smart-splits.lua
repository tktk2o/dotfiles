return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  keys = {
    { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left pane" },
    { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to below pane" },
    { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to above pane" },
    { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right pane" },
  },
}
