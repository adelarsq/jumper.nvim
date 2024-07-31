-- [nfnl] Compiled from fnl/jumper/init.fnl by https://github.com/Olical/nfnl, do not edit.
local files = (vim.g.file_list or {})
local function add_current_file()
  local current_file = vim.fn.expand("%:p")
  if not vim.tbl_contains(files, current_file) then
    table.insert(files, current_file)
    vim.g.file_list = files
    return nil
  else
    return nil
  end
end
local function get_file_list()
  for i, file in ipairs(files) do
    vim.api.nvim_echo("Test", false, {})
  end
  return nil
end
local function navigate_to_file(index)
  local file = nth(files, index)
  if file then
    return vim.cmd(("edit " .. file))
  else
    return nil
  end
end
vim.api.nvim_create_user_command("AddCurrentFile", add_current_file, {})
vim.api.nvim_create_user_command("GetFileList", get_file_list, {})
local function _3_(opts)
  return navigate_to_file(tonumber(vim.fn.input("Enter file index: ")))
end
return vim.api.nvim_create_user_command("NavigateToFile", _3_, {})
