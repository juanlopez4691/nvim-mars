-- Shared terminal manager for the TUI terminals that lazygit.lua,
-- scooter.lua, plugins/opencode.lua, and the generic <leader>t terminal run.
-- Each terminal is a tracked window running a job via `jobstart(term=true)`,
-- torn down (window closed, job stopped, buffer wiped) when its window
-- closes or its process exits. Entering a terminal window drops straight
-- into terminal mode; double-<Esc> returns to normal mode, where `q` closes
-- the terminal.

local M = {}

---@class mars.helpers.term.Term
---@field id string
---@field cmd string[]
---@field buf integer
---@field win integer?
---@field job integer
---@field esc_timer uv.uv_timer_t

---@type table<string, mars.helpers.term.Term>
local terms = {}

---@param opts { id?: string, cmd: string|string[], count?: integer }
---@return string
local function id_for(opts)
  return vim.inspect({ id = opts.id, cmd = opts.cmd, count = opts.count or vim.v.count1 })
end

---@param win integer?
---@return boolean
local function is_valid_win(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

--- Stops the job (if still running) and wipes the buffer, then removes the
--- entry from the registry. Idempotent.
---@param term mars.helpers.term.Term
local function cleanup(term)
  if terms[term.id] == term then
    terms[term.id] = nil
  end
  if term.job and vim.fn.jobwait({ term.job }, 0)[1] == -1 then
    vim.fn.jobstop(term.job)
  end
  term.job = nil
  local buf = term.buf
  term.buf, term.win = nil, nil
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

--- Closes the tracked window, or cleans up directly if it's already gone.
--- Closing the window wipes the buffer (bufhidden=wipe), which terminates
--- the job.
---@param term mars.helpers.term.Term
local function close_term(term)
  if not term then
    return
  end
  if is_valid_win(term.win) then
    vim.api.nvim_win_close(term.win, true)
  else
    cleanup(term)
  end
end

--- Opens the tracked buffer in a window, registering teardown for it. Used
--- at creation and to surface a terminal that was started hidden.
---@param term mars.helpers.term.Term
---@param win_config table
---@param focus boolean
local function attach_win(term, win_config, focus)
  term.win = vim.api.nvim_open_win(term.buf, focus, win_config)
  vim.wo[term.win].number = false
  vim.wo[term.win].relativenumber = false
  vim.wo[term.win].list = false
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(term.win),
    once = true,
    callback = function()
      cleanup(term)
    end,
  })
end

--- Creates a terminal running `cmd`, tracking it in the registry and wiring
--- job-exit/WinClosed teardown. `jobstart` with `term = true` attaches to the
--- *current* buffer, so the fresh buffer is made current via `nvim_buf_call`
--- (autocmd-free, focus untouched). With `show = false` the process runs
--- hidden (no window) until `M.open`/`M.toggle` surfaces it. Returns the
--- term, or nil if the job failed to start.
---@param opts { id?: string, cmd: string|string[], cwd?: string, win_config: table, focus?: boolean, show?: boolean, count?: integer }
---@return mars.helpers.term.Term?
local function create(opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local term = {
    id = id_for(opts),
    cmd = type(opts.cmd) == "table" and opts.cmd or { opts.cmd },
    buf = buf,
    win = nil,
    win_config = opts.win_config,
    esc_timer = vim.uv.new_timer(),
  }
  terms[term.id] = term

  -- Entering the terminal window drops into terminal mode (also on the first
  -- open, so the autocmd is registered before the window is entered).
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      vim.cmd.startinsert()
    end,
  })

  -- Double <Esc> returns to normal mode; a single <Esc> still reaches the
  -- TUI (e.g. opencode's own cancel/back handling).
  vim.keymap.set("t", "<Esc>", function()
    if term.esc_timer:is_active() then
      term.esc_timer:stop()
      vim.cmd("stopinsert")
    else
      term.esc_timer:start(200, 0, function() end)
      return "<Esc>"
    end
  end, { expr = true, buffer = buf, desc = "Terminal: double Esc to normal mode" })

  -- Normal mode inside a terminal buffer: `q` closes (and kills) the
  -- terminal. Sending the TUI its own `q` requires terminal mode.
  vim.keymap.set("n", "q", function()
    close_term(term)
  end, { buffer = buf, desc = "Terminal: close" })

  -- In terminal mode, <C-h/j/k/l> navigate to the adjacent split (tmux
  -- style): exit terminal mode, then move focus. Single keypresses the shell
  -- would otherwise eat (e.g. <C-h> backspace) are sacrificed for this.
  for _, dir in ipairs({ "h", "j", "k", "l" }) do
    vim.keymap.set("t", "<C-" .. dir .. ">", ("<C-\\><C-n><C-w>%s"):format(dir), {
      buffer = buf,
      desc = ("Terminal: focus %s"):format(dir),
    })
  end

  local job = vim.api.nvim_buf_call(buf, function()
    return vim.fn.jobstart(opts.cmd, {
      term = true,
      cwd = opts.cwd,
      -- Pin the pty to the window's requested size: interactive shells
      -- otherwise report their own size and resize the split (a "30%"
      -- bottom terminal would balloon to ~80% of the screen).
      height = opts.win_config.height,
      width = opts.win_config.width,
      on_exit = function()
        vim.schedule(function()
          if terms[term.id] == term then
            close_term(term)
          end
        end)
      end,
    })
  end)

  if job <= 0 then
    vim.notify("failed to start the terminal job", vim.log.levels.ERROR)
    if is_valid_win(term.win) then
      vim.api.nvim_win_close(term.win, true)
    else
      cleanup(term)
    end
    return nil
  end
  term.job = job

  if opts.show ~= false then
    attach_win(term, opts.win_config, opts.focus ~= false)
  end

  return term
end

--- The registered terminal for `cmd`, if still alive.
---@param opts { id?: string, cmd: string|string[], count?: integer }
---@return mars.helpers.term.Term?
function M.get(opts)
  return terms[id_for(opts)]
end

--- Opens (or focuses, unless `focus` is false) the terminal for `cmd`,
--- surfacing it in a window if it was started hidden.
---@param opts { id?: string, cmd: string|string[], cwd?: string, win_config?: table, focus?: boolean, count?: integer }
---@return mars.helpers.term.Term?
function M.open(opts)
  local term = terms[id_for(opts)]
  if term then
    local focus = opts.focus ~= false
    if is_valid_win(term.win) then
      if focus then
        vim.api.nvim_set_current_win(term.win)
      end
    else
      attach_win(term, opts.win_config or term.win_config, focus)
    end
    return term
  end
  return create(opts)
end

--- Toggles the terminal for `cmd`: closes it when it's the current window,
--- focuses it when it's open elsewhere, surfaces a hidden one, opens it
--- otherwise.
---@param opts { id?: string, cmd: string|string[], cwd?: string, win_config?: table, count?: integer }
---@return mars.helpers.term.Term?
function M.toggle(opts)
  local term = terms[id_for(opts)]
  if term then
    if is_valid_win(term.win) then
      if vim.api.nvim_get_current_win() == term.win then
        close_term(term)
      else
        vim.api.nvim_set_current_win(term.win)
      end
    else
      attach_win(term, opts.win_config or term.win_config, true)
    end
    return term
  end
  return create(opts)
end

--- Closes the terminal for `cmd`, terminating its job.
---@param opts { id?: string, cmd: string|string[], count?: integer }
function M.close(opts)
  close_term(terms[id_for(opts)])
end

--- Re-applies `win_config` to the tracked window, e.g. to keep a float
--- centered and sized after a `VimResized`.
---@param opts { id?: string, cmd: string|string[], count?: integer }
---@param win_config table
function M.recenter(opts, win_config)
  local term = terms[id_for(opts)]
  if term and is_valid_win(term.win) then
    vim.api.nvim_win_set_config(term.win, win_config)
  end
end

--- Centered-float window config for the TUI terminals, sized as fractions of
--- the editor. `vim.g.mars_float_terminal_size` overrides the size (e.g.
--- `{ width = 0.8, height = 0.7 }`); read at call time so local.lua overrides
--- apply. (This sizes the *floating* terminals; the generic split terminals
--- use `mars_split_terminal_size`.)
---@return vim.api.keyset.win_config
function M.float_geometry()
  local size = type(vim.g.mars_float_terminal_size) == "table" and vim.g.mars_float_terminal_size or {}
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
