-- Session save/restore on :mksession, keyed to the working directory.
-- Saving runs automatically on exit; restoring is always explicit
-- (:MarsSessionRestore/RestoreLast/List or their keymaps); silently
-- reopening buffers on startup would be surprising.

local M = {}

local session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions")

--- Worth restoring: buffer list, cwd, tab/window layout, sizing, folds.
--- Blank/empty windows, terminals, and help windows are left out.
local SESSION_OPTIONS = "buffers,curdir,folds,tabpages,winsize"

--- Percent-encodes anything outside a safe alphanumeric core, so path
--- separators, spaces, and colons round-trip losslessly into one filename.
---@param str string
---@return string
local function encode(str)
  return (str:gsub("[^%w%-%._]", function(char)
    return ("%%%02X"):format(char:byte())
  end))
end

--- Reverses `encode`, so a session filename shows the directory it belongs to.
---@param str string
---@return string
local function decode(str)
  return (str:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

---@param cwd? string Defaults to the current working directory.
---@return string
local function session_path(cwd)
  return vim.fs.joinpath(session_dir, encode(cwd or vim.uv.cwd()) .. ".vim")
end

--- Whether the current run is worth persisting: skips runs started with
--- explicit file args (an ad hoc `nvim somefile` shouldn't overwrite that
--- directory's session) and runs with no listed, named, normal buffer
--- (scratch or a nofile landing screen).
---@return boolean
local function worth_saving()
  if vim.fn.argc(-1) > 0 then
    return false
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      if vim.api.nvim_buf_get_name(buf) ~= "" and vim.bo[buf].buftype == "" then
        return true
      end
    end
  end

  return false
end

local skip_save = false

--- Marks this instance as not-to-be-saved on exit (:MarsSessionStop), for
--- one-off runs that shouldn't clobber a directory's saved session.
function M.stop()
  skip_save = true
end

--- Writes the session file for the current directory, creating the dir on
--- demand. Notifies rather than raising, since this runs from VimLeavePre
--- where an uncaught error would abort quitting.
function M.save()
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, "p")
  end

  local previous = vim.o.sessionoptions
  vim.o.sessionoptions = SESSION_OPTIONS

  local ok, err = pcall(vim.cmd, ("mksession! %s"):format(vim.fn.fnameescape(session_path())))

  vim.o.sessionoptions = previous

  if not ok then
    vim.notify(("Failed to save session: %s"):format(err), vim.log.levels.WARN)
  end
end

--- Restores the session file for the current directory, if one exists.
function M.restore()
  local path = session_path()
  if vim.fn.filereadable(path) == 0 then
    vim.notify(("No saved session for %s"):format(vim.uv.cwd()), vim.log.levels.WARN)
    return
  end

  local ok, err = pcall(vim.cmd, ("source %s"):format(vim.fn.fnameescape(path)))
  if not ok then
    vim.notify(("Failed to restore session: %s"):format(err), vim.log.levels.ERROR)
  end
end

---@return string[]
local function saved_sessions()
  return vim.fn.glob(vim.fs.joinpath(session_dir, "*.vim"), true, true)
end

--- Restores whichever session was written most recently, regardless of
--- which directory it belongs to.
function M.restore_last()
  local files = saved_sessions()
  if #files == 0 then
    vim.notify("No saved sessions found", vim.log.levels.WARN)
    return
  end

  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)

  local ok, err = pcall(vim.cmd, ("source %s"):format(vim.fn.fnameescape(files[1])))
  if not ok then
    vim.notify(("Failed to restore session: %s"):format(err), vim.log.levels.ERROR)
  end
end

--- Presents every saved session as a `vim.ui.select` menu (decoded back to
--- its directory) and restores the chosen one.
function M.list()
  local files = saved_sessions()
  if #files == 0 then
    vim.notify("No saved sessions found", vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, file in ipairs(files) do
    items[#items + 1] = { path = file, cwd = decode(vim.fn.fnamemodify(file, ":t:r")) }
  end

  vim.ui.select(items, {
    prompt = "Restore session",
    format_item = function(item)
      return item.cwd
    end,
  }, function(choice)
    if not choice then
      return
    end

    local ok, err = pcall(vim.cmd, ("source %s"):format(vim.fn.fnameescape(choice.path)))
    if not ok then
      vim.notify(("Failed to restore session: %s"):format(err), vim.log.levels.ERROR)
    end
  end)
end

local augroup = vim.api.nvim_create_augroup("mars_session", { clear = true })

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = augroup,
  desc = "Save a session for the current directory on exit",
  callback = function()
    if not skip_save and worth_saving() then
      M.save()
    end
  end,
})

vim.api.nvim_create_user_command("MarsSessionRestore", function()
  M.restore()
end, { desc = "Restore the session for the current directory" })

vim.api.nvim_create_user_command("MarsSessionRestoreLast", function()
  M.restore_last()
end, { desc = "Restore the most recently saved session" })

vim.api.nvim_create_user_command("MarsSessionStop", function()
  M.stop()
end, { desc = "Don't save a session for this run on exit" })

vim.api.nvim_create_user_command("MarsSessionList", function()
  M.list()
end, { desc = "Pick a saved session to restore" })

vim.keymap.set("n", "<leader>qs", "<cmd>MarsSessionRestore<cr>", { silent = true, desc = "Restore for cwd" })
vim.keymap.set("n", "<leader>ql", "<cmd>MarsSessionRestoreLast<cr>", { silent = true, desc = "Restore last" })
vim.keymap.set("n", "<leader>qd", "<cmd>MarsSessionStop<cr>", { silent = true, desc = "Don't save this one" })
vim.keymap.set("n", "<leader>qf", "<cmd>MarsSessionList<cr>", { silent = true, desc = "Find/list" })

return M
