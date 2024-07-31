-- [nfnl] Compiled from fnl/jumper/init.fnl by https://github.com/Olical/nfnl, do not edit.
if vim.g.loaded_jumper then
  return 
else
end
local M = {}
local files = (vim.g.file_list or {})
local function add_current_file()
  local current_file = vim.fn.expand("%:p")
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
  vim.api.nvim_echo({{"Current file list:", "None"}}, false, {})
  local list = {}
  for i, file in ipairs(files) do
    vim.api.nvim_echo({{(i .. ": " .. file), "None"}}, false, {})
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
    return vim.api.nvim_echo({{("Invalid index: " .. index), "ErrorMsg"}}, false, {})
  end
end
vim.api.nvim_create_user_command("JumperAdd", add_current_file, {})
vim.api.nvim_create_user_command("JumperList", get_file_list, {})
local function _4_(opts)
  return navigate_to_file(tonumber(vim.fn.input("Enter file index: ")))
end
vim.api.nvim_create_user_command("JumperJump", _4_, {})
M.setup = function()
  vim.g.loaded_jumper = 1
  return nil
end
return M
