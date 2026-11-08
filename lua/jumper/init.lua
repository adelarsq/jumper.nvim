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
  db:eval("CREATE TABLE IF NOT EXISTS files (\n    file text not null,\n    path text not null\n  )")
  return db:eval("CREATE TABLE IF NOT EXISTS bookmarks (\n    file text not null,\n    path text not null,\n    lnum integer not null,\n    note text not null\n  )")
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
local function load_bookmarks_for_dir(dir)
  local db = get_db(get_db_path_for_cwd())
  ensure_table(db)
  local rows = db:eval("select file, lnum, note from bookmarks where path = :path order by file, lnum", {path = dir})
  if (type(rows) == "table") then
    local tbl_26_ = {}
    local i_27_ = 0
    for _, row in ipairs(rows) do
      local val_28_ = {file = row.file, lnum = row.lnum, note = row.note}
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
local function save_bookmark(dir, file, lnum, note)
  local db = get_db(get_db_path_for_cwd())
  ensure_table(db)
  db:eval("delete from bookmarks where path = :path and file = :file and lnum = :lnum", {path = dir, file = file, lnum = lnum})
  return db:eval("insert into bookmarks (path, file, lnum, note) values (:path, :file, :lnum, :note)", {path = dir, file = file, lnum = lnum, note = note})
end
local function remove_bookmarks_for_file(dir, file)
  local db = get_db(get_db_path_for_cwd())
  ensure_table(db)
  return db:eval("delete from bookmarks where path = :path and file = :file", {path = dir, file = file})
end
local files = {}
local bookmarks = {}
local current_dir = vim.fn.getcwd()
local function clear_files_table()
  while (#files > 0) do
    table.remove(files)
  end
  return nil
end
local function clear_bookmarks_table()
  while (#bookmarks > 0) do
    table.remove(bookmarks)
  end
  return nil
end
local function reload_files()
  local dir = vim.fn.getcwd()
  local persisted_files = load_files_for_dir(dir)
  local persisted_bookmarks = load_bookmarks_for_dir(dir)
  current_dir = dir
  clear_files_table()
  for _, f in ipairs(persisted_files) do
    table.insert(files, f)
  end
  clear_bookmarks_table()
  for _, b in ipairs(persisted_bookmarks) do
    table.insert(bookmarks, b)
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
local function bookmark_exists_3f(file, lnum)
  local found = false
  for _, b in ipairs(bookmarks) do
    if ((b.file == file) and (b.lnum == lnum)) then
      found = true
    else
    end
  end
  return found
end
local function remove_bookmark_from_memory(file, lnum)
  local new_list = {}
  for _, b in ipairs(bookmarks) do
    if not ((b.file == file) and (b.lnum == lnum)) then
      table.insert(new_list, b)
    else
    end
  end
  clear_bookmarks_table()
  for _, b in ipairs(new_list) do
    table.insert(bookmarks, b)
  end
  return nil
end
local function add_bookmark()
  local current_file = get_current_file_path()
  if ((current_file == "") or not vim.bo.modifiable or (vim.bo.buftype == "terminal")) then
    return vim.api.nvim_echo({{"Cannot bookmark this buffer.", "WarningMsg"}}, false, {})
  else
    if not vim.tbl_contains(files, current_file) then
      table.insert(files, current_file)
      persist_files()
    else
    end
    local lnum = vim.fn.line(".")
    local default = ("line " .. lnum)
    local note = vim.fn.input(("Bookmark comment for line " .. lnum .. ": "), default)
    if (note == "") then
      return vim.api.nvim_echo({{"Bookmark cancelled.", "WarningMsg"}}, false, {})
    else
      save_bookmark(current_dir, current_file, lnum, note)
      remove_bookmark_from_memory(current_file, lnum)
      table.insert(bookmarks, {file = current_file, lnum = lnum, note = note})
      return vim.api.nvim_echo({{("Bookmarked " .. vim.fn.fnamemodify(current_file, ":t") .. ":" .. lnum .. " -> " .. note)}}, false, {})
    end
  end
end
local function get_file_list()
  if ((#files == 0) and (#bookmarks == 0)) then
    return vim.api.nvim_echo({{"No files or bookmarks in the list.", "WarningMsg"}}, false, {})
  else
    local items = {}
    for _, file in ipairs(files) do
      table.insert(items, {kind = "file", filename = file, text = vim.fn.fnamemodify(file, ":~")})
      for _0, b in ipairs(bookmarks) do
        if (b.file == file) then
          table.insert(items, {kind = "bookmark", filename = file, lnum = b.lnum, note = b.note, text = ("  \226\148\148\226\148\128 " .. b.lnum .. ": " .. b.note)})
        else
        end
      end
    end
    for _, b in ipairs(bookmarks) do
      if not vim.tbl_contains(files, b.file) then
        table.insert(items, {kind = "bookmark", filename = b.file, lnum = b.lnum, note = b.note, text = (vim.fn.fnamemodify(b.file, ":~") .. " \226\148\148\226\148\128 " .. b.lnum .. ": " .. b.note)})
      else
      end
    end
    local function _23_(item)
      return item.text
    end
    local function _24_(choice)
      if choice then
        if (choice.kind == "file") then
          return vim.cmd(("edit " .. vim.fn.fnameescape(choice.filename)))
        else
          vim.cmd(("edit " .. vim.fn.fnameescape(choice.filename)))
          vim.api.nvim_win_set_cursor(0, {choice.lnum, 0})
          return vim.cmd("normal! zz")
        end
      else
        return nil
      end
    end
    return vim.ui.select(items, {prompt = "Select file or bookmark:", format_item = _23_, kind = "jumper"}, _24_)
  end
end
local function get_file_list_quickfix()
  local list = {}
  for _, file in ipairs(files) do
    table.insert(list, {filename = file, text = vim.fn.fnamemodify(file, ":~")})
  end
  for _, b in ipairs(bookmarks) do
    table.insert(list, {filename = b.file, lnum = b.lnum, text = ("  \226\148\148\226\148\128 " .. b.lnum .. ": " .. b.note)})
  end
  vim.fn.setqflist(list)
  return vim.cmd("bel copen 10")
end
local function remove_current_file()
  local current_file = get_current_file_path()
  if ((current_file == "") or not vim.tbl_contains(files, current_file)) then
    return vim.api.nvim_echo({{"Current file is not in the list.", "WarningMsg"}}, false, {})
  else
    local confirm = vim.fn.confirm(("Remove \"" .. vim.fn.fnamemodify(current_file, ":~") .. "\" (and its bookmarks) from the list?"), "&Yes\n&No", 2)
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
      local new_bms = {}
      for _, b in ipairs(bookmarks) do
        if (b.file ~= current_file) then
          table.insert(new_bms, b)
        else
        end
      end
      clear_bookmarks_table()
      for _, b in ipairs(new_bms) do
        table.insert(bookmarks, b)
      end
      persist_files()
      remove_bookmarks_for_file(current_dir, current_file)
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
    local confirm = vim.fn.confirm(("Clear all " .. #files .. " file(s) and their bookmarks from the list?"), "&Yes\n&No", 2)
    if (confirm == 1) then
      clear_files_table()
      clear_bookmarks_table()
      persist_files()
      do
        local db = get_db(get_db_path_for_cwd())
        ensure_table(db)
        db:eval("delete from bookmarks where path = :path", {path = current_dir})
      end
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
    return vim.cmd(("edit " .. vim.fn.fnameescape(file)))
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
    if (current_index < 1) then
      return navigate_to_file(len)
    else
      local current_dir0 = get_file_dir(files[current_index])
      local prev_index = nil
      for offset = 1, len do
        if not prev_index then
          local candidate_index
          if ((current_index - offset) <= 0) then
            candidate_index = ((current_index - offset) + len)
          else
            candidate_index = (current_index - offset)
          end
          if (get_file_dir(files[candidate_index]) == current_dir0) then
            prev_index = candidate_index
          else
          end
        else
        end
      end
      if prev_index then
        return navigate_to_file(prev_index)
      else
        return vim.api.nvim_echo({{"No other file from the same directory in the list.", "WarningMsg"}}, false, {})
      end
    end
  end
end
local function navigate_to_previous_file_global()
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
local function _54_()
  reload_files()
  return vim.api.nvim_echo({{("Jumper: carregada lista para " .. vim.fn.getcwd())}}, false, {})
end
vim.api.nvim_create_autocmd("DirChanged", {callback = _54_})
vim.api.nvim_create_user_command("JumperAdd", add_current_file, {})
vim.api.nvim_create_user_command("JumperAddBookmark", add_bookmark, {})
vim.api.nvim_create_user_command("JumperList", get_file_list, {})
vim.api.nvim_create_user_command("JumperListQF", get_file_list_quickfix, {})
vim.api.nvim_create_user_command("JumperClear", clear_file_list, {})
vim.api.nvim_create_user_command("JumperRemove", remove_current_file, {})
vim.api.nvim_create_user_command("JumperNext", navigate_to_next_file, {})
vim.api.nvim_create_user_command("JumperNextGlobal", navigate_to_next_file_global, {})
vim.api.nvim_create_user_command("JumperPrevious", navigate_to_previous_file, {})
vim.api.nvim_create_user_command("JumperPreviousGlobal", navigate_to_previous_file_global, {})
M.setup = function()
  vim.g.loaded_jumper = 1
  return nil
end
return M
