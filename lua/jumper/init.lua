-- [nfnl] fnl/jumper/init.fnl
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
local function clear_file_list()
  vim.g.file_list = {}
  return nil
end
local function navigate_to_file(index)
  local file = vim.fn.get(files, index)
  if file then
    return vim.cmd(("edit " .. file))
  else
    return nil
  end
end
local function navigate_to_next_file()
  local current_index = vim.fn.index(files, vim.fn.expand("%:p"))
  local next_index
  if ((current_index + 1) == #files) then
    next_index = 0
  else
    next_index = (current_index + 1)
  end
  return navigate_to_file(next_index)
end
vim.t.terminal_bufnr = nil
local function toggle_or_open_terminal()
  if (vim.t.terminal_bufnr and vim.api.nvim_buf_is_valid(vim.t.terminal_bufnr)) then
    if (vim.api.nvim_get_current_buf() == vim.t.terminal_bufnr) then
      return vim.api.nvim_command("b#")
    elseif vim.api.nvim_command(("buffer " .. vim.t.terminal_bufnr)) then
      return vim.api.nvim_feedkeys("i", "n", false)
    else
      return nil
    end
  else
    vim.api.nvim_command("enew")
    vim.api.nvim_command("terminal")
    vim.t.terminal_bufnr = vim.api.nvim_get_current_buf()
    return vim.api.nvim_feedkeys("i", "n", false)
  end
end
vim.api.nvim_create_user_command("JumperAdd", add_current_file, {})
vim.api.nvim_create_user_command("JumperList", get_file_list, {})
vim.api.nvim_create_user_command("JumperClear", clear_file_list, {})
local function _11_(opts)
  return navigate_to_file(tonumber(vim.fn.input("Enter file index: ")))
end
vim.api.nvim_create_user_command("JumperJump", _11_, {})
vim.api.nvim_create_user_command("JumperNext", navigate_to_next_file, {})
vim.api.nvim_create_user_command("JumperTerminal", toggle_or_open_terminal, {})
M.setup = function()
  vim.g.loaded_jumper = 1
  return nil
end
return M
