-- Shared lifecycle for the terminal windows that lazygit.lua, scooter.lua,
-- and plugins/opencode.lua each run a TUI in: open a tracked terminal, tear
-- it down when its job exits or its window closes, and keep it recentered.

local M = {}

---@class mars.term.State
---@field win integer?
---@field buf integer?
---@field job integer?

---@param win integer?
---@return boolean
local function is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

--- Stops the job (if still running) and wipes the buffer, then clears
--- `state`. Assumes the window is already gone or going away on its own.
---@param state mars.term.State
function M.cleanup(state)
  if state.job and vim.fn.jobwait({ state.job }, 0)[1] == -1 then
    vim.fn.jobstop(state.job)
  end
  state.job = nil

  local buf = state.buf
  state.buf, state.win = nil, nil
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

--- Closes the tracked window. Job/buffer cleanup happens via the `WinClosed`
--- autocmd registered at open, so the "user closed it" and "we closed it"
--- paths converge.
---@param state mars.term.State
function M.close(state)
  if is_valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  else
    M.cleanup(state)
  end
end

--- The tracked window if it's still valid, else nil.
---@param state mars.term.State
---@return integer?
function M.win(state)
  return is_valid_win(state.win) and state.win or nil
end

--- Focuses the tracked window. Returns whether it did.
---@param state mars.term.State
---@return boolean
function M.focus(state)
  local win = M.win(state)
  if win then
    vim.api.nvim_set_current_win(win)
    return true
  end
  return false
end

--- Opens a terminal running `cmd` in a new window (float or split, per
--- `win_config`), tracking it in `state` and wiring job-exit/WinClosed
--- teardown. Returns the winid, or nil if the job failed to start. Does not
--- focus a window that's already open; callers check `M.win` first.
---@param state mars.term.State
---@param opts { cmd: string[], cwd: string, win_config: table, focus?: boolean }
---@return integer?
function M.open(state, opts)
  M.cleanup(state)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, opts.focus ~= false, opts.win_config)

  local job = vim.fn.jobstart(opts.cmd, {
    term = true,
    cwd = opts.cwd,
    on_exit = function()
      vim.schedule(function()
        -- Skip a stale exit from a session already replaced.
        if state.job == job then
          M.close(state)
        end
      end)
    end,
  })

  if job <= 0 then
    vim.notify("failed to start the terminal job", vim.log.levels.ERROR)
    vim.api.nvim_win_close(win, true)
    return nil
  end

  state.win, state.buf, state.job = win, buf, job

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      M.cleanup(state)
    end,
  })

  return win
end

--- Re-applies `win_config` to the tracked window, e.g. to keep a float
--- centered and sized after a `VimResized`.
---@param state mars.term.State
---@param win_config table
function M.recenter(state, win_config)
  local win = M.win(state)
  if win then
    vim.api.nvim_win_set_config(win, win_config)
  end
end

--- Centered-float window config for the TUI terminals, sized as fractions of
--- the editor. `vim.g.mars_term_size` overrides the size (e.g. `{ width = 0.8,
--- height = 0.7 }`); read at call time so local.lua overrides apply.
---@return vim.api.keyset.win_config
function M.float_geometry()
  local size = type(vim.g.mars_term_size) == "table" and vim.g.mars_term_size or {}
  local width = math.floor(vim.o.columns * (size.width or 0.9))
  local height = math.floor(vim.o.lines * (size.height or 0.9))
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

return M
