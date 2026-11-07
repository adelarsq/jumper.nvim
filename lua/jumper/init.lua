-- [nfnl] fnl/jumper/init.fnl
if vim.g.loaded_jumper then
  return 
else
end
local M = {}
local sqlite = require("sqlite.db")
local db_connections = {}
local function get_global_db_path()
  local data_dir = vim.fn.stdpath("data")
  local jumper_dir = (data_dir .. "/jumper")
  vim.fn.mkdir(jumper_dir, "p")
  return (jumper_dir .. "/global.db")
end
local function find_git_root(start_dir)
  local dir = start_dir
  local found = nil
  while (dir and not found and (dir ~= "")) do
    do
      local git_dir = (dir .. "/.git")
      if (1 == vim.fn.isdirectory(git_dir)) then
        found = dir
      else
      end
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if (parent == dir) then
      dir = nil
    else
      dir = parent
    end
  end
  return found
end
local function get_db_path_for_cwd()
  local cwd = vim.fn.getcwd()
  local git_root = find_git_root(cwd)
  if git_root then
    local data_dir = vim.fn.stdpath("data")
    local jumper_dir = (data_dir .. "/jumper")
    local hash = vim.fn.sha256(git_root)
    local short_hash = string.sub(hash, 1, 16)
    vim.fn.mkdir(jumper_dir, "p")
    return (jumper_dir .. "/repo-" .. short_hash .. ".db")
  else
    return get_global_db_path()
  end
end
local function get_db(path)
  local or_5_ = db_connections[path]
  if not or_5_ then
    local db = sqlite:open(path)
    db_connections[path] = db
    or_5_ = db
  end
  return or_5_
end
local function ensure_table(db)
  return db:eval("CREATE TABLE IF NOT EXISTS files (\n    file text not null,\n    path text not null\n  )")
end
local function load_files_for_dir(dir)
  local db = get_db(get_db_path_for_cwd())
  ensure_table(db)
  local rows = db:eval("select file from files where path = :path order by rowid", {path = dir})
  if (type(rows) == "table") then
    local tbl_26_ = {}
    local i_27_ = 0
    for _, row in ipairs(rows) do
      local val_28_ = row.file
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  else
    return {}
  end
end
local function save_files_for_dir(dir, file_list)
  local db = get_db(get_db_path_for_cwd())
  ensure_table(db)
  db:eval("delete from files where path = :path", {path = dir})
  for _, file in ipairs(file_list) do
    db:eval("insert into files (path, file) values (:path, :file)", {path = dir, file = file})
  end
  return nil
end
local files = {}
local current_dir = vim.fn.getcwd()
local function clear_files_table()
  while (#files > 0) do
    table.remove(files)
  end
  return nil
end
local function reload_files()
  local dir = vim.fn.getcwd()
  local persisted = load_files_for_dir(dir)
  current_dir = dir
  clear_files_table()
  for _, f in ipairs(persisted) do
    table.insert(files, f)
  end
  vim.g.file_list = files
  return nil
end
local function persist_files()
  save_files_for_dir(current_dir, files)
  vim.g.file_list = files
  return nil
end
reload_files()
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
local function get_current_file_path()
  local current_file = ""
  local filetype = vim.bo.filetype
  if (filetype == "oil") then
    current_file = get_oil_file_path()
  elseif (filetype == "NvimTree") then
    current_file = get_nvim_tree_file_path()
  else
    current_file = vim.fn.expand("%:p")
  end
  return current_file
end
local function add_current_file()
  local current_file = get_current_file_path()
  if (current_file and (current_file ~= "") and not vim.tbl_contains(files, current_file)) then
    table.insert(files, current_file)
    persist_files()
    return vim.api.nvim_echo({{("Added " .. current_file .. " to the list.")}}, false, {})
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
    local function _14_(item)
      return (item.index .. ": " .. vim.fn.fnamemodify(item.filename, ":~"))
    end
    local function _15_(choice)
      if choice then
        return vim.cmd(("edit " .. choice.filename))
      else
        return nil
      end
    end
    return vim.ui.select(items, {prompt = "Select file to open:", format_item = _14_, kind = "file"}, _15_)
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
local function remove_current_file()
  local current_file = get_current_file_path()
  if ((current_file == "") or not vim.tbl_contains(files, current_file)) then
    return vim.api.nvim_echo({{"Current file is not in the list.", "WarningMsg"}}, false, {})
  else
    local confirm = vim.fn.confirm(("Remove \"" .. vim.fn.fnamemodify(current_file, ":~") .. "\" from the list?"), "&Yes\n&No", 2)
    if (confirm == 1) then
      local new_list = {}
      for _, file in ipairs(files) do
        if (file ~= current_file) then
          table.insert(new_list, file)
        else
        end
      end
      clear_files_table()
      for _, file in ipairs(new_list) do
        table.insert(files, file)
      end
      persist_files()
      return vim.api.nvim_echo({{("Removed " .. vim.fn.fnamemodify(current_file, ":~") .. " from the list.")}}, false, {})
    else
      return nil
    end
  end
end
local function clear_file_list()
  if (#files == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local confirm = vim.fn.confirm(("Clear all " .. #files .. " file(s) from the list?"), "&Yes\n&No", 2)
    if (confirm == 1) then
      clear_files_table()
      persist_files()
      return vim.api.nvim_echo({{"File list cleared.", "WarningMsg"}}, false, {})
    else
      return nil
    end
  end
end
local function navigate_to_file(index)
  local len = #files
  if (index and (index >= 1) and (index <= len)) then
    local file = files[index]
    return vim.cmd(("edit " .. file))
  else
    return vim.api.nvim_echo({{("Invalid index: " .. (index or "nil") .. ". Valid range: 1-" .. len), "ErrorMsg"}}, false, {})
  end
end
local function get_current_file_index()
  local current_file = vim.fn.expand("%:p")
  local len = #files
  local found_index = -1
  for i = 1, len do
    if (files[i] == current_file) then
      found_index = i
    else
    end
  end
  return found_index
end
local function get_file_dir(path)
  return vim.fn.fnamemodify(path, ":h")
end
local function navigate_to_next_file()
  local len = #files
  if (len == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local current_index = get_current_file_index()
    if (current_index < 1) then
      return navigate_to_file(1)
    else
      local current_dir0 = get_file_dir(files[current_index])
      local next_index = nil
      for offset = 1, len do
        if not next_index then
          local candidate_index
          if ((current_index + offset) > len) then
            candidate_index = ((current_index + offset) - len)
          else
            candidate_index = (current_index + offset)
          end
          if (get_file_dir(files[candidate_index]) == current_dir0) then
            next_index = candidate_index
          else
          end
        else
        end
      end
      if next_index then
        return navigate_to_file(next_index)
      else
        return vim.api.nvim_echo({{"No other file from the same directory in the list.", "WarningMsg"}}, false, {})
      end
    end
  end
end
local function navigate_to_next_file_global()
  local len = #files
  if (len == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local current_index = get_current_file_index()
    if (current_index >= 1) then
      local next_index
      if (current_index == len) then
        next_index = 1
      else
        next_index = (current_index + 1)
      end
      return navigate_to_file(next_index)
    else
      return navigate_to_file(1)
    end
  end
end
local function navigate_to_previous_file()
  local len = #files
  if (len == 0) then
    return vim.api.nvim_echo({{"No files in the list.", "WarningMsg"}}, false, {})
  else
    local current_index = get_current_file_index()
    if (current_index >= 1) then
      local prev_index
      if (current_index == 1) then
        prev_index = len
      else
        prev_index = (current_index - 1)
      end
      return navigate_to_file(prev_index)
    else
      return navigate_to_file(len)
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
local function _39_()
  reload_files()
  return vim.api.nvim_echo({{("Jumper: carregada lista para " .. vim.fn.getcwd())}}, false, {})
end
vim.api.nvim_create_autocmd("DirChanged", {callback = _39_})
vim.api.nvim_create_user_command("JumperAdd", add_current_file, {})
vim.api.nvim_create_user_command("JumperList", get_file_list, {})
vim.api.nvim_create_user_command("JumperListQF", get_file_list_quickfix, {})
vim.api.nvim_create_user_command("JumperClear", clear_file_list, {})
vim.api.nvim_create_user_command("JumperRemove", remove_current_file, {})
vim.api.nvim_create_user_command("JumperNext", navigate_to_next_file, {})
vim.api.nvim_create_user_command("JumperNextGlobal", navigate_to_next_file_global, {})
vim.api.nvim_create_user_command("JumperPrevious", navigate_to_previous_file, {})
vim.api.nvim_create_user_command("JumperTerminal", toggle_or_open_terminal, {})
M.setup = function()
  vim.g.loaded_jumper = 1
  return nil
end
return M
