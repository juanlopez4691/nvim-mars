-- NickvanDyke/opencode.nvim: chat/agent integration with the OpenCode CLI,
-- the sole AI surface in this config, no Copilot (see AGENTS.md's approved
-- exception list). Everything below lives under `<leader>o*`; `<leader>a`
-- is a separate reserved namespace (see README's keymap table) and stays
-- untouched here.
--
-- opencode.nvim has no `setup()` call; it reads `vim.g.opencode_opts`
-- lazily, the first time any of its own modules is `require()`d. Setting
-- that global below is just table construction (no plugin code runs), so
-- every actual `require("opencode")` inside the keymaps further down stays
-- the true lazy-load point; the same effect `mars.pack.on()` gives other
-- plugins, without needing an event/ft/cmd trigger to hang it on (compare
-- `lua/mars/plugins/fzf-lua.lua`, which lazy-loads the same way).
--
-- `opencode_opts.server.start` launches `opencode --port` in a right-side
-- split terminal, using the same hand-rolled `jobstart(..., { term = true
-- })` + `WinClosed` cleanup approach as `lua/mars/core/lazygit.lua`, just
-- a right split instead of a centered float. It's kept local to this file
-- (rather than promoted to `core/`) since it exists solely to satisfy this
-- plugin's terminal contract; see `lazygit.lua` for the fuller rationale on
-- the pattern itself.
--
-- Adapted to the currently-tracked opencode.nvim API (checked against its
-- README and source, since `vim.pack.add()` tracks the default branch, not
-- a pinned release):
--   - `ask()` now takes only a `default` prefill string; the old
--     `{ submit, focus }` opts are gone, so every "quick ask" below opens
--     an editable prompt instead of silently auto-submitting.
--   - `@diff` no longer exists as a context placeholder (`@diagnostics`
--     replaces it; see upstream's `lua/opencode/context/builtins.lua`), so
--     `<leader>od` asks about `@diagnostics` instead of a diff.
--   - `session.close` isn't a real server command (see the command table in
--     opencode.nvim's README); `<leader>oc` now closes the terminal
--     itself instead, which ends the session in practice.
--   - the old `<leader>oI` was a duplicate of `<leader>oa` now that `ask()`
--     dropped the `focus` option that used to distinguish them, so it's
--     dropped here rather than kept as dead weight.
--   - terminal toggle/stop stay normal-mode only, not `{ "n", "t" }`: with
--     a space leader (`init.lua`), a terminal-mode leader mapping adds
--     input delay to every literal space typed inside *any* terminal
--     buffer while Neovim waits to see whether a mapping follows;
--     opencode.nvim's own README warns about exactly this trade-off.

require("mars.pack").add({
  { src = "https://github.com/NickvanDyke/opencode.nvim" },
})

local augroup = vim.api.nvim_create_augroup("mars_opencode", { clear = true })

---@type { win: integer?, buf: integer?, job: integer? }
local state = { win = nil, buf = nil, job = nil }

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

--- Stops the job (if still running) and wipes the buffer, then clears all
--- tracked state. Assumes the window is already gone or going away on its
--- own, mirroring `lazygit.lua`'s `cleanup()`.
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

--- Closes the terminal split. Cleanup of the job/buffer happens via the
--- `WinClosed` autocmd registered when the window was opened, so both the
--- "user closed it" and "we closed it programmatically" paths converge.
local function close()
  if is_valid_win(state.win) then
    vim.api.nvim_win_close(state.win, true)
  else
    cleanup()
  end
end

--- Opens (or focuses) the OpenCode terminal in a right-side split,
--- starting `opencode --port` when there isn't one running yet. Used both
--- as `opencode_opts.server.start` (unfocused; opencode.nvim triggers
--- this on demand, behind the scenes) and by the `<leader>ot` toggle
--- (focused).
---@param opts { focus?: boolean }?
local function open(opts)
  local focus = opts == nil or opts.focus ~= false

  if is_valid_win(state.win) then
    if focus then
      vim.api.nvim_set_current_win(state.win)
      vim.cmd.startinsert()
    end
    return
  end

  -- A previous run may have left a stale buffer/job behind (e.g. the
  -- window was closed some other way before this state was cleared).
  cleanup()

  if vim.fn.executable("opencode") == 0 then
    vim.notify("opencode not found on PATH; install it to use OpenCode", vim.log.levels.ERROR)
    return
  end

  local root = vim.fs.root(0, ".git") or vim.uv.cwd()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, focus, {
    split = "right",
    win = -1,
    width = math.floor(vim.o.columns * 0.4),
  })

  local job = vim.fn.jobstart({ "opencode", "--port" }, {
    term = true,
    cwd = root,
    on_exit = function()
      vim.schedule(close)
    end,
  })

  if job <= 0 then
    vim.notify("failed to start the opencode terminal job", vim.log.levels.ERROR)
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

  if focus then
    vim.cmd.startinsert()
  end
end

--- Closes the terminal when it's the current window, otherwise opens/
--- focuses it, the usual "toggle" contract for a side-split terminal.
local function toggle()
  if is_valid_win(state.win) and vim.api.nvim_get_current_win() == state.win then
    close()
  else
    open({ focus = true })
  end
end

---@type opencode.Opts
vim.g.opencode_opts = {
  server = {
    start = function()
      open({ focus = false })
    end,
  },
}

--- Opens an editable OpenCode ask prompt pre-filled with `default`.
---@param default string
---@return fun()
local function ask(default)
  return function()
    require("opencode").ask(default)
  end
end

--- Submits a prompt to OpenCode immediately, with no editable prompt box.
---@param text string
---@return fun()
local function prompt(text)
  return function()
    require("opencode").prompt(text)
  end
end

--- Sends a named OpenCode server command (session/scroll/etc; see the
--- command table in opencode.nvim's README).
---@param name string
---@return fun()
local function command(name)
  return function()
    require("opencode").command(name)
  end
end

-- Ask, by context scope. Each opens an editable prompt pre-filled with the
-- placeholder, rather than auto-submitting (see the header note on `ask()`
-- losing its `{ submit, focus }` opts).
vim.keymap.set({ "n", "x" }, "<leader>oa", ask("@this: "), { desc = "Ask" })
vim.keymap.set({ "n", "x" }, "<leader>ob", ask("@buffer: "), { desc = "Ask (buffer)…" })
vim.keymap.set({ "n", "x" }, "<leader>oB", ask("@buffers: "), { desc = "Ask (buffers)…" })
vim.keymap.set({ "n", "x" }, "<leader>od", ask("@diagnostics: "), { desc = "Ask (diagnostics)…" })
vim.keymap.set({ "n", "x" }, "<leader>om", ask("@marks: "), { desc = "Ask (marks)…" })
vim.keymap.set({ "n", "x" }, "<leader>ov", ask("@visible: "), { desc = "Ask (visible)…" })
vim.keymap.set({ "n", "x" }, "<leader>ox", ask("@quickfix: "), { desc = "Ask (quickfix)…" })
vim.keymap.set({ "n", "x" }, "<leader>oi", ask(""), { desc = "Ask (empty)…" })

-- Prompts: act on `@this` (range/selection, else cursor) immediately.
vim.keymap.set({ "n", "x" }, "<leader>of", prompt("@this fix: "), { desc = "Fix" })
vim.keymap.set({ "n", "x" }, "<leader>oe", prompt("@this explain: "), { desc = "Explain" })
vim.keymap.set({ "n", "x" }, "<leader>or", prompt("@this review: "), { desc = "Review" })
vim.keymap.set({ "n", "x" }, "<leader>oo", prompt("@this optimize: "), { desc = "Optimize" })
vim.keymap.set({ "n", "x" }, "<leader>os", prompt("@this test: "), { desc = "Test" })
vim.keymap.set({ "n", "x" }, "<leader>oD", prompt("@this diagnose: "), { desc = "Diagnose" })

-- Operator-mode: send a motion's range (or the current line) to OpenCode.
-- `go`/`goo` mirror opencode.nvim's own recommended keymaps (README); the
-- `<leader>o*` variants exist alongside them for discoverability via
-- which-key.
vim.keymap.set({ "n", "x" }, "<leader>og", function()
  return require("opencode").operator("@this ")
end, { expr = true, desc = "Add Range" })

vim.keymap.set("n", "<leader>ol", function()
  return require("opencode").operator("@this ") .. "_"
end, { expr = true, desc = "Add Line" })

vim.keymap.set({ "n", "x" }, "go", function()
  return require("opencode").operator("@this ")
end, { expr = true, desc = "OpenCode: Add Range" })

vim.keymap.set("n", "goo", function()
  return require("opencode").operator("@this ") .. "_"
end, { expr = true, desc = "OpenCode: Add Line" })

-- Session management. `session.close` doesn't exist server-side (see the
-- header note), so "close" here means closing the terminal that's running
-- the session.
vim.keymap.set("n", "<leader>on", command("session.new"), { desc = "New Session" })
vim.keymap.set("n", "<leader>oc", close, { desc = "Close Session" })

-- Terminal: `opencode --port` in a right split (see `open()`/`toggle()`
-- above).
vim.keymap.set("n", "<leader>ot", toggle, { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>oq", close, { desc = "Stop/Close Terminal" })

-- Action/prompt picker.
vim.keymap.set({ "n", "x" }, "<leader>oX", function()
  require("opencode").select()
end, { desc = "Execute Action…" })

-- Scroll the OpenCode terminal's message pane.
vim.keymap.set("n", "<leader>ou", command("session.half.page.up"), { desc = "Scroll Up" })
vim.keymap.set("n", "<leader>oj", command("session.half.page.down"), { desc = "Scroll Down" })
