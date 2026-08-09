-- Scooter (https://github.com/thomasschafer/scooter), an interactive
-- find-and-replace TUI, in a centered floating terminal.
--
-- Pressing `e` on a scooter search result shells out to whatever command is
-- configured as its editor-open command, substituting `%file`/`%line` for
-- the selected result first (scooter's own contract; see `scooter --help`
-- and its README's "Configuration options" > `[editor_open]` and "Editor
-- configuration" > "Neovim" sections). scooter has no RPC of its own: the
-- documented way to land that edit in an *already running* Neovim is to
-- have the editor-open command itself invoke `nvim --server $NVIM
-- --remote-send` (`:help remote-send`) against this instance. `$NVIM` is
-- set automatically in every terminal job Neovim starts (`:help
-- jobstart-env`); the same mechanism lazygit.lua's `nvim-remote` pairing
-- relies on. Unlike lazygit, scooter needs no merged temp config file: its
-- `--editor-command` flag "overrides config file setting" outright, so the
-- user's own `~/.config/scooter/config.toml` (themes, keybindings, ...) is
-- never touched.
--
-- scooter's upstream Neovim recipe routes `--remote-send` through a bare
-- `_G` global (`_G.EditLineFromScooter`). This repo's AGENTS.md forbids
-- introducing new globals from first-party code, so `jump_to_result` below
-- is called via `require("mars.core.scooter")` instead; `require` isn't a
-- new global, and it returns the same module table `init.lua` already
-- loaded at startup.

local M = {}

local augroup = vim.api.nvim_create_augroup("mars_scooter", { clear = true })

---@type { win: integer?, buf: integer?, job: integer?, root: string? }
local state = { win = nil, buf = nil, job = nil, root = nil }

---@param win integer?
---@return boolean
local function is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

---@param buf integer?
---@return boolean
local function is_valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

---@return vim.api.keyset.win_config
local function win_geometry()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = require("mars.ui.borders").style(),
  }
end

--- Stops the job (if still running) and wipes the buffer, then clears all
--- tracked state. Assumes the window is already gone or going away on its
--- own; this never closes it, so it's safe to call from a `WinClosed`
--- handler for that same window without recursing back into one.
local function cleanup()
  if state.job and vim.fn.jobwait({ state.job }, 0)[1] == -1 then
    vim.fn.jobstop(state.job)
  end
  state.job = nil

  local buf = state.buf
  state.buf, state.win = nil, nil
  if is_valid_buf(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

--- Closes the float. Cleanup of the job/buffer happens via the `WinClosed`
--- autocmd registered when the window was opened, so both the "user closed
--- it" and "we're closing it programmatically" paths converge on the same
--- code.
local function close()
  if is_valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  else
    cleanup()
  end
end

--- The command scooter runs (via its own shell) when `e` is pressed on a
--- search result. Passed through `--editor-command` rather than baked into
--- scooter's config file. `%file`/`%line` are substituted by scooter itself
--- before the string is executed; `$NVIM` is expanded by scooter's own
--- subshell from the environment it inherited from this terminal job.
local EDITOR_COMMAND =
  [[nvim --server $NVIM --remote-send '<cmd>lua require("mars.core.scooter").jump_to_result("%file", %line)<CR>']]

--- Called back by scooter (see `EDITOR_COMMAND` above) when a search result
--- is opened with `e`. scooter reports `file_path` relative to the
--- directory it searched (the root `open`/`open_with_selection` launched it
--- in), so a relative path is resolved against that root; an already
--- absolute path is used as-is.
---
--- Opens the result in a new tab and leaves the scooter float, and its
--- still-running job, untouched in the background, the same
--- "already-running instance" trick lazygit.lua gets from `--remote-tab`.
--- scooter only reports a line, not a column (see `scooter --help`), so the
--- cursor lands at column 0.
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
--- is closed first when `extra_args` is given, since pre-populated fields
--- (e.g. `--search-text`) can't be applied to a session already in
--- progress; otherwise an existing window is just refocused. Notifies
--- instead of opening an empty terminal when scooter isn't installed.
---@param extra_args string[]? Extra CLI args, e.g. to pre-populate search text.
local function start(extra_args)
  if extra_args and is_valid_win(state.win) then
    close()
  end

  if is_valid_win(state.win) then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd.startinsert()
    return
  end

  -- A previous run may have left a stale buffer/job behind (e.g. the window
  -- was closed some other way before this state was cleared).
  cleanup()

  if vim.fn.executable("scooter") == 0 then
    vim.notify("scooter not found on PATH; install it to use :MarsScooter", vim.log.levels.ERROR)
    return
  end

  local root = vim.fs.root(0, ".git") or vim.uv.cwd()
  state.root = root

  local cmd = { "scooter", "--editor-command", EDITOR_COMMAND }
  vim.list_extend(cmd, extra_args or {})

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, win_geometry())

  local job
  job = vim.fn.jobstart(cmd, {
    term = true,
    cwd = root,
    on_exit = function()
      -- Guard against a stale exit from a session `start()` already
      -- replaced (see the `close()` call above): only tear down the float
      -- if it's still tracking *this* job.
      vim.schedule(function()
        if state.job == job then
          close()
        end
      end)
    end,
  })

  if job <= 0 then
    vim.notify("failed to start the scooter terminal job", vim.log.levels.ERROR)
    vim.api.nvim_win_close(win, true)
    return
  end

  state.win, state.buf, state.job = win, buf, job

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(win),
    once = true,
    callback = cleanup,
  })

  vim.cmd.startinsert()
end

--- Opens scooter in the project root.
function M.open()
  start()
end

--- Grabs the last visual selection's text via `getregion()` (no registers
--- touched, unlike a yank-and-restore dance) and opens scooter with it
--- pre-populated as a fixed-string search term. Newlines are flattened to
--- spaces, since scooter's search field is single-line unless multiline
--- mode is explicitly enabled.
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
    if is_valid_win(state.win) then
      vim.api.nvim_win_set_config(state.win, win_geometry())
    end
  end,
})

vim.api.nvim_create_user_command("MarsScooter", M.open, { desc = "Open scooter (find & replace)" })

vim.keymap.set("n", "<leader>ss", M.open, { desc = "Open scooter (find & replace)" })
vim.keymap.set("v", "<leader>ss", M.open_with_selection, { desc = "Search selected text in scooter" })

return M
