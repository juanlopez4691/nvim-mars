-- Session save/restore built on :mksession, keyed to the working
-- directory so each project gets its own session file. Saving happens
-- automatically on exit; restoring is always an explicit action
-- (:MarsSessionRestore/:MarsSessionRestoreLast/:MarsSessionList, or their
-- keymaps below); silently reopening buffers on startup would be
-- surprising, so this module never does that on its own.

local M = {}

local session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions")

--- Narrower than a do-everything sessionoptions: buffer list, working
--- directory, tab/window layout, sizing, and folds are worth restoring.
--- Blank/empty windows, terminal buffers, and help windows don't survive a
--- restore usefully, so they're deliberately left out rather than dragged
--- along.
local SESSION_OPTIONS = "buffers,curdir,folds,tabpages,winsize"

--- Percent-encodes everything outside a safe alphanumeric core, so path
--- separators, spaces, colons, and any other filesystem-hostile byte in a
--- cwd round-trip losslessly into one flat filename instead of being
--- guessed at case by case.
---@param str string
---@return string
local function encode(str)
  return (str:gsub("[^%w%-%._]", function(char)
    return ("%%%02X"):format(char:byte())
  end))
end

--- Reverses `encode`, so a session filename can be shown back to the user
--- as the directory it belongs to.
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

--- Whether the current window/buffer state is worth persisting. Skips runs
--- started with explicit file arguments; an ad hoc `nvim somefile` edit
--- shouldn't silently overwrite that directory's real project session with
--- just that one file, and skips runs where no listed buffer has both a
--- name and a normal buftype, which covers an empty scratch buffer and a
--- buftype=nofile landing screen (e.g. a dashboard) alike.
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

--- Marks the current instance as not-to-be-saved on exit. Exposed as
--- :MarsSessionStop for one-off runs (a quick peek at a directory, scratch
--- exploration) that shouldn't clobber that directory's saved session.
function M.stop()
  skip_save = true
end

--- Writes the session file for the current directory. Creates the session
--- directory on demand and notifies rather than raising if the write fails,
--- since this runs from VimLeavePre where an uncaught error would abort
--- quitting.
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

--- Restores whichever saved session was written to most recently,
--- regardless of which directory it belongs to.
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

--- Presents every saved session as a `vim.ui.select` menu, decoded back to
--- the directory it belongs to, and restores whichever one is chosen.
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
