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
      do local _ = (dir .. file_name) end
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
    do local _ = entry.absolute_path end
  else
  end
  return ""
end
local function add_current_file()
  local current_file = ""
  local filetype = vim.bo.filetype
  if (filetype == "oil") then
    current_file = get_oil_file_path()
  elseif (filetype == "NvimTree") then
    current_file = get_nvim_tree_file_path()
  else
    current_file = vim.fn.expand("%:p")
  end
  if (current_file and (current_file ~= "") and not vim.tbl_contains(files, current_file)) then
    table.insert(files, current_file)
    vim.api.nvim_echo({{("Added " .. current_file .. " to the list.")}}, false, {})
    vim.g.file_list = files
    return nil
  else
    return nil
  end
end
local function get_file_list()
  if (#files == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local items = {}
    for i, file in ipairs(files) do
      table.insert(items, {index = i, filename = file, text = file})
    end
    local function _7_(item)
      return (item.index .. ": " .. vim.fn.fnamemodify(item.filename, ":~"))
    end
    local function _8_(choice)
      if choice then
        vim.cmd(("edit " .. choice.filename))
        local qf_list = {}
        for i, file in ipairs(files) do
          table.insert(qf_list, {filename = file, text = ""})
        end
        return vim.fn.setqflist(qf_list)
      else
        return nil
      end
    end
    return vim.ui.select(items, {prompt = "Select file to open:", format_item = _7_, kind = "file"}, _8_)
  end
end
local function get_file_list_quickfix()
  local list = {}
  for i, file in ipairs(files) do
    local dic = {filename = file, text = (i .. ": " .. vim.fn.fnamemodify(file, ":~"))}
    table.insert(list, dic)
  end
  vim.fn.setqflist(list)
  return vim.cmd("bel copen 10")
end
local function clear_file_list()
  vim.g.file_list = {}
  return vim.api.nvim_echo({{"File list cleared.", "WarningMsg"}}, false, {})
end
local function navigate_to_file(index)
  if (index and (index >= 1) and (index <= #files)) then
    local file = files[index]
    return vim.cmd(("edit " .. file))
  else
    return vim.api.nvim_echo({{("Invalid index: " .. (index or "nil")), "ErrorMsg"}}, false, {})
  end
end
local function navigate_to_file_select()
  if (#files == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local items = {}
    for i, file in ipairs(files) do
      table.insert(items, {index = i, filename = file, text = file})
    end
    local function _12_(item)
      return (item.index .. ": " .. vim.fn.fnamemodify(item.filename, ":~"))
    end
    local function _13_(choice)
      if choice then
        return vim.cmd(("edit " .. choice.filename))
      else
        return nil
      end
    end
    return vim.ui.select(items, {prompt = "Jump to file:", format_item = _12_, kind = "file"}, _13_)
  end
end
local function navigate_to_next_file()
  if (#files == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local current_index = vim.fn.index(files, vim.fn.expand("%:p"))
    if (current_index >= 0) then
      local next_index
      if ((current_index + 1) == #files) then
        next_index = 0
      else
        next_index = (current_index + 1)
      end
      return navigate_to_file(next_index)
    else
      return vim.api.nvim_echo({{"Current file not in the list. Use JumperJump to select.", "WarningMsg"}}, false, {})
    end
  end
end
vim.t.terminal_bufnr = nil
local function toggle_or_open_terminal()
  if (vim.t.terminal_bufnr and vim.api.nvim_buf_is_valid(vim.t.terminal_bufnr)) then
    if (vim.api.nvim_get_current_buf() == vim.t.terminal_bufnr) then
      return vim.api.nvim_command("b#")
    else
      vim.api.nvim_command(("buffer " .. vim.t.terminal_bufnr))
      return vim.api.nvim_feedkeys("i", "n", false)
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
vim.api.nvim_create_user_command("JumperListQF", get_file_list_quickfix, {})
vim.api.nvim_create_user_command("JumperClear", clear_file_list, {})
local function _21_(opts)
  if (#files == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    if (opts.count and (opts.count > 0)) then
      return navigate_to_file(opts.count)
    else
      return navigate_to_file_select()
    end
  end
end
vim.api.nvim_create_user_command("JumperJump", _21_, {count = true})
vim.api.nvim_create_user_command("JumperNext", navigate_to_next_file, {})
vim.api.nvim_create_user_command("JumperTerminal", toggle_or_open_terminal, {})
M.setup = function()
  vim.g.loaded_jumper = 1
  return nil
end
return M
