-- Lazygit in a centered floating terminal.
--
-- Edits triggered from inside lazygit (the `e` keybinding) land in this
-- already-running instance instead of spawning a nested Neovim. Every
-- terminal job Neovim starts (via `:terminal` or `jobstart(..., { term =
-- true })`) gets `$NVIM` set in its environment to `v:servername` of the
-- parent process (`:help $NVIM`, `:help jobstart-env`); that's automatic,
-- nothing here sets it by hand. The other half is lazygit's own `nvim-remote`
-- editor preset, which shells out to `nvim --server "$NVIM" --remote-tab
-- {{filename}}` instead of a plain `nvim {{filename}}` (see lazygit's
-- `pkg/config/editor_presets.go`). That preset has to come from lazygit's
-- config, so it's supplied via `--use-config-file` with a small generated
-- override layered on top of the user's own global lazygit config (when one
-- exists); nothing in `~/.config/lazygit` is touched.

local M = {}

local augroup = vim.api.nvim_create_augroup("mars_lazygit", { clear = true })

---@type { win: integer?, buf: integer?, job: integer? }
local state = { win = nil, buf = nil, job = nil }

--- Cached result of `lazygit --print-config-dir`: nil until looked up once,
--- then either the directory (string) or `false` if the lookup failed.
--- Can't change within a session, so the blocking `vim.fn.system` call only
--- ever runs once instead of on every `open()`.
---@type string|boolean|nil
local lazygit_config_dir = nil

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
    border = "rounded",
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

--- Writes (once) a small lazygit config snippet that forces the
--- `nvim-remote` editor preset, and returns the value to hand to
--- `--use-config-file`: that override alone, or the user's own global
--- config followed by the override when one is found, so lazygit still
--- merges the user's own settings underneath it.
---@return string
local function editor_config_arg()
  local override = vim.fs.joinpath(vim.fn.stdpath("cache"), "mars-lazygit-editor.yml")
  vim.fn.writefile({ "os:", '  editPreset: "nvim-remote"' }, override)

  if lazygit_config_dir == nil then
    local config_dir = vim.fn.system({ "lazygit", "--print-config-dir" })
    lazygit_config_dir = vim.v.shell_error == 0 and vim.trim(config_dir) or false
  end

  if lazygit_config_dir then
    local default_config = vim.fs.joinpath(lazygit_config_dir, "config.yml")
    if vim.fn.filereadable(default_config) == 1 then
      return default_config .. "," .. override
    end
  end

  return override
end

--- Opens lazygit in a centered floating window, reusing the existing one if
--- it's already open. Notifies instead of opening an empty terminal when
--- lazygit isn't installed.
function M.open()
  if is_valid_win(state.win) then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd.startinsert()
    return
  end

  -- A previous run may have left a stale buffer/job behind (e.g. the window
  -- was closed some other way before this state was cleared).
  cleanup()

  if vim.fn.executable("lazygit") == 0 then
    vim.notify("lazygit not found on PATH; install it to use :MarsLazygit", vim.log.levels.ERROR)
    return
  end

  local root = vim.fs.root(0, ".git") or vim.uv.cwd()
  local config_arg = editor_config_arg()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win = vim.api.nvim_open_win(buf, true, win_geometry())

  local job = vim.fn.jobstart({ "lazygit", "--use-config-file", config_arg }, {
    term = true,
    cwd = root,
    on_exit = function()
      vim.schedule(close)
    end,
  })

  if job <= 0 then
    vim.notify("failed to start the lazygit terminal job", vim.log.levels.ERROR)
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

vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  desc = "Keep the lazygit float centered and sized to the current window",
  callback = function()
    if is_valid_win(state.win) then
      vim.api.nvim_win_set_config(state.win, win_geometry())
    end
  end,
})

vim.api.nvim_create_user_command("MarsLazygit", M.open, { desc = "Open lazygit in a floating window" })

vim.keymap.set("n", "<leader>gg", M.open, { desc = "Open lazygit" })

return M
