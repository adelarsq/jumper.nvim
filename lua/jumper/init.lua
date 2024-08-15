-- [nfnl] Compiled from fnl/jumper/init.fnl by https://github.com/Olical/nfnl, do not edit.
if vim.g.loaded_jumper then
  return 
else
end
local M = {}
local files = (vim.g.file_list or {})
local function get_oil_file_path()
  local use, imported = pcall(require, "oil")
  if use then
    local entry = imported.get_cursor_entry()
    if (entry.type == "file") then
      local dir = imported.get_current_dir()
      local file_name = entry.name
      local full_name = (dir .. file_name)
      local return1 = full_name
      return return1
    else
    end
  else
  end
  return ""
end
local function get_nvim_tree_file_path()
  local use, imported = pcall(require, "nvim-tree.lib")
  if use then
    local entry = imported.get_node_at_cursor()
    local return1 = entry.absolute_path
    return return1
  else
  end
  return ""
end
local function add_current_file()
  local current_file = ""
  local filetype = vim.bo.filetype
  if (filetype == "oil") then
    current_file = get_oil_file_path({})
  elseif (filetype == "NvimTree") then
    current_file = get_nvim_tree_file_path({})
  else
    current_file = vim.fn.expand("%:p")
  end
  if not vim.tbl_contains(files, current_file) then
    table.insert(files, current_file)
    vim.api.nvim_echo({{("Added " .. current_file .. " to the list.")}}, false, {})
    vim.g.file_list = files
    return nil
  else
    return nil
  end
end
local function get_file_list()
  local list = {}
  for i, file in ipairs(files) do
    local dic = {filename = file, text = ""}
    table.insert(list, dic)
  end
  vim.fn.setqflist(list)
  return vim.cmd("bel copen 10")
end
local function navigate_to_file(index)
  local file = nth(files, index)
  if file then
    return vim.cmd(("edit " .. file))
  else
    return nil
  end
end
vim.api.nvim_create_user_command("JumperAdd", add_current_file, {})
vim.api.nvim_create_user_command("JumperList", get_file_list, {})
local function _8_(opts)
  return navigate_to_file(tonumber(vim.fn.input("Enter file index: ")))
end
vim.api.nvim_create_user_command("JumperJump", _8_, {})
M.setup = function()
  vim.g.loaded_jumper = 1
  return nil
end
return M
