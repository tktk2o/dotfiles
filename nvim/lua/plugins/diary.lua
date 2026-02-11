-- 日報（daily report）即時生成
-- テンプレート: ~/docs/diary/template/template.md
-- 生成先:      ~/docs/diary/YYYY-MM-DD.md

local template_path = vim.fn.expand("~/docs/diary/template/template.md")
local diary_dir = vim.fn.expand("~/docs/diary")

local weekdays = { "日", "月", "火", "水", "木", "金", "土" }

local function open_diary(offset)
  offset = offset or 0
  local time = os.time() + offset * 86400
  local date = os.date("%Y-%m-%d", time)
  local weekday = weekdays[tonumber(os.date("%w", time)) + 1]
  local filename = diary_dir .. "/" .. date .. ".md"

  if vim.fn.filereadable(filename) == 1 then
    vim.cmd.edit(filename)
    return
  end

  -- テンプレート読み込み & プレースホルダー置換
  local lines = {}
  if vim.fn.filereadable(template_path) == 1 then
    lines = vim.fn.readfile(template_path)
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("{{date}}", date):gsub("{{weekday}}", weekday)
    end
  end

  vim.fn.mkdir(diary_dir, "p")
  vim.fn.writefile(lines, filename)
  vim.cmd.edit(filename)
end

vim.api.nvim_create_user_command("DiaryToday", function() open_diary(0) end, {})
vim.api.nvim_create_user_command("DiaryYesterday", function() open_diary(-1) end, {})
vim.keymap.set("n", "<leader>dd", function() open_diary(0) end, { desc = "Today's diary" })
vim.keymap.set("n", "<leader>dy", function() open_diary(-1) end, { desc = "Yesterday's diary" })

return {}
