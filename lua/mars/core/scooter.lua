-- Scooter (https://github.com/thomasschafer/scooter), an interactive
-- find-and-replace TUI, in a centered floating terminal. `e` on a search
-- result routes back into this instance via --server/--remote-send (see
-- EDITOR_COMMAND); the user's own ~/.config/scooter/config.toml is untouched.

local M = {}

local term = require("mars.helpers.term")

---@type mars.helpers.term.State & { root: string? }
local state = { win = nil, buf = nil, job = nil, root = nil }

local augroup = vim.api.nvim_create_augroup("mars_scooter", { clear = true })

local EDITOR_COMMAND =
  [[nvim --server $NVIM --remote-send '<cmd>lua require("mars.core.scooter").jump_to_result("%file", %line)<CR>']]

--- Called back by scooter (see `EDITOR_COMMAND`) when a result is opened
--- with `e`. Relative paths resolve against the root scooter searched; the
--- float is left running in the background.
---@param file_path string
---@param line integer
function M.jump_to_result(file_path, line)
  local target = file_path
  if not vim.startswith(target, "/") and state.root then
    target = vim.fs.joinpath(state.root, file_path)
  end

  vim.cmd.tabedit(vim.fn.fnameescape(target))
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
end

--- Opens scooter in a centered floating window. Any already-running session
--- is closed first when `extra_args` is given (pre-filled fields can't be
--- applied to a session already in progress); otherwise an existing window
--- is just refocused. Notifies instead of opening an empty terminal when
--- scooter isn't installed.
---@param extra_args string[]? Extra CLI args, e.g. to pre-populate search text.
local function start(extra_args)
  if extra_args and term.win(state) then
    term.close(state)
  end

  if term.focus(state) then
    vim.cmd.startinsert()
    return
  end

  if vim.fn.executable("scooter") == 0 then
    vim.notify("scooter not found on PATH; install it to use :MarsScooter", vim.log.levels.ERROR)
    return
  end

  state.root = vim.fs.root(0, ".git") or vim.uv.cwd()

  local cmd = { "scooter", "--editor-command", EDITOR_COMMAND }
  vim.list_extend(cmd, extra_args or {})

  local win = term.open(state, {
    cmd = cmd,
    cwd = state.root,
    win_config = term.float_geometry(),
  })
  if win then
    vim.cmd.startinsert()
  end
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
    term.recenter(state, term.float_geometry())
  end,
})

vim.api.nvim_create_user_command("MarsScooter", M.open, { desc = "Open scooter (find & replace)" })

vim.keymap.set("n", "<leader>ss", M.open, { desc = "Open scooter (find & replace)" })
vim.keymap.set("v", "<leader>ss", M.open_with_selection, { desc = "Search selected text in scooter" })

return M
