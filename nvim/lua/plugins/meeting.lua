-- ミーティングノート即時生成
-- テンプレート: ~/docs/meetings/template/template.md
-- 生成先:      ~/docs/meetings/YYYY-MM-DD_名前.md

local template_path = vim.fn.expand("~/docs/meetings/template/template.md")
local meetings_dir = vim.fn.expand("~/docs/meetings")

local function create_meeting_note()
  local name = vim.fn.input("Meeting name: ")
  if name == "" then
    return
  end

  local date = os.date("%Y-%m-%d")
  local filename = meetings_dir .. "/" .. date .. "_" .. name .. ".md"

  if vim.fn.filereadable(filename) == 1 then
    vim.notify("Already exists: " .. filename, vim.log.levels.WARN)
    vim.cmd.edit(filename)
    return
  end

  -- テンプレート読み込み & プレースホルダー置換
  local lines = {}
  if vim.fn.filereadable(template_path) == 1 then
    lines = vim.fn.readfile(template_path)
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("{{title}}", name):gsub("{{date}}", date)
    end
  end

  vim.fn.mkdir(meetings_dir, "p")
  vim.fn.writefile(lines, filename)
  vim.cmd.edit(filename)
end

vim.api.nvim_create_user_command("MeetingNew", create_meeting_note, {})
vim.keymap.set("n", "<leader>mm", create_meeting_note, { desc = "New meeting note" })

return {}
