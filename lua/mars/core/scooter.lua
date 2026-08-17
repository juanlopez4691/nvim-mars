-- Scooter (https://github.com/thomasschafer/scooter), an interactive
-- find-and-replace TUI, in a centered floating terminal. `e` on a search
-- result routes back into this instance via --server/--remote-send (see
-- EDITOR_COMMAND); the user's own ~/.config/scooter/config.toml is untouched.

local M = {}

local term = require("mars.helpers.term")

local augroup = vim.api.nvim_create_augroup("mars_scooter", { clear = true })

local EDITOR_COMMAND =
  [[nvim --server $NVIM --remote-send '<cmd>lua require("mars.core.scooter").jump_to_result("%file", %line)<CR>']]

--- The root scooter last searched, for resolving relative paths in
--- `jump_to_result`. `last_cmd` tracks the exact launch args so a re-launch
--- with pre-filled fields can close the previous session.
---@type string|nil
local root = nil
---@type string[]|nil
local last_cmd = nil

--- Called back by scooter (see `EDITOR_COMMAND`) when a result is opened
--- with `e`. Relative paths resolve against the root scooter searched; the
--- float is left running in the background.
---@param file_path string
---@param line integer
function M.jump_to_result(file_path, line)
  local target = file_path
  if not vim.startswith(target, "/") and root then
    target = vim.fs.joinpath(root, file_path)
  end

  vim.cmd.tabedit(vim.fn.fnameescape(target))
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
end

---@param extra_args string[]
---@return string[]
local function cmd(extra_args)
  local c = { "scooter", "--editor-command", EDITOR_COMMAND }
  vim.list_extend(c, extra_args)
  return c
end

--- Opens scooter in a centered floating window. A launch with `extra_args`
--- (pre-filled search fields) closes any previous scooter session first;
--- those fields can't be applied to a session already in progress; a plain
--- relaunch just refocuses. Notifies instead of opening an empty terminal
--- when scooter isn't installed.
---@param extra_args string[]? Extra CLI args, e.g. to pre-populate search text.
local function start(extra_args)
  if vim.fn.executable("scooter") == 0 then
    vim.notify("scooter not found on PATH; install it to use :MarsScooter", vim.log.levels.ERROR)
    return
  end

  if extra_args and last_cmd and term.get({ cmd = last_cmd, count = 1 }) then
    term.close({ cmd = last_cmd, count = 1 })
  end

  local c = cmd(extra_args or {})
  last_cmd = c
  root = vim.fs.root(0, ".git") or vim.uv.cwd()

  term.open({
    cmd = c,
    cwd = root,
    win_config = term.float_geometry(),
    count = 1,
  })
end

--- Opens scooter in the project root.
function M.open()
  start()
end

--- Grabs the last visual selection's text via `getregion()` and opens scooter
--- with it pre-populated as a fixed-string search term. Newlines flatten to
--- spaces, since scooter's search field is single-line.
function M.open_with_selection()
  local mode = vim.fn.visualmode()
  local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = mode })
  local text = table.concat(lines, " ")

  if text == "" then
    M.open()
    return
  end

  start({ "--fixed-strings", "--search-text", text })
end

vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  desc = "Keep the scooter float centered and sized to the current window",
  callback = function()
    term.recenter({ cmd = last_cmd or cmd({}), count = 1 }, term.float_geometry())
  end,
})

vim.api.nvim_create_user_command("MarsScooter", M.open, { desc = "Open scooter (find & replace)" })

vim.keymap.set("n", "<leader>ss", M.open, { desc = "Open scooter (find & replace)" })
vim.keymap.set("v", "<leader>ss", M.open_with_selection, { desc = "Search selected text in scooter" })

return M
