-- NickvanDyke/opencode.nvim: chat/agent integration with the OpenCode CLI,
-- the sole AI surface in this config. Everything lives under `<leader>o*`;
-- `<leader>a` is a separate reserved namespace and stays untouched here.
--
-- No `setup()` call: opencode.nvim reads `vim.g.opencode_opts` lazily on the
-- first `require()`, so the require()s inside the keymaps below stay the true
-- lazy-load point. `opencode_opts.server.start` launches `opencode --port`
-- in a right-side split (jobstart term + WinClosed cleanup, as in
-- lua/mars/core/lazygit.lua).
--
-- Adapted to the currently-tracked API (pack tracks the default branch, not
-- a pinned release): `ask()` takes only a `default` prefill; the old
-- `{ submit, focus }` opts are gone, so quick asks open an editable prompt;
-- `@diff` is gone (`@diagnostics` replaces it, hence `<leader>od`); and
-- `session.close` isn't a real command, so `<leader>oc` closes the terminal
-- itself. Terminal toggles stay normal-mode only: with a space leader, a
-- terminal-mode leader mapping delays every literal space typed in a
-- terminal buffer.

require("mars.pack").add({
  { src = "https://github.com/NickvanDyke/opencode.nvim" },
})

local term = require("mars.term")

---@type mars.term.State
local state = { win = nil, buf = nil, job = nil }

--- Opens (or focuses) the terminal in a right-side split, starting
--- `opencode --port` when none is running. Doubles as `opencode_opts.server.start`
--- (unfocused, behind the scenes) and the `<leader>ot` toggle (focused).
---@param opts { focus?: boolean }?
local function open(opts)
  local focus = opts == nil or opts.focus ~= false

  if term.win(state) then
    if focus then
      vim.api.nvim_set_current_win(state.win)
      vim.cmd.startinsert()
    end
    return
  end

  if vim.fn.executable("opencode") == 0 then
    vim.notify("opencode not found on PATH; install it to use OpenCode", vim.log.levels.ERROR)
    return
  end

  local win = term.open(state, {
    cmd = { "opencode", "--port" },
    cwd = vim.fs.root(0, ".git") or vim.uv.cwd(),
    focus = focus,
    win_config = {
      split = "right",
      win = -1,
      width = math.floor(vim.o.columns * 0.4),
    },
  })
  if win and focus then
    vim.cmd.startinsert()
  end
end

--- Closes the terminal when it's the current window, otherwise opens/
--- focuses it, the usual toggle contract for a side-split terminal.
local function toggle()
  if term.win(state) and vim.api.nvim_get_current_win() == state.win then
    term.close(state)
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

--- Sends a named OpenCode server command (session/scroll/etc).
---@param name string
---@return fun()
local function command(name)
  return function()
    require("opencode").command(name)
  end
end

-- Ask, by context scope. Each opens an editable prompt pre-filled with the
-- placeholder rather than auto-submitting (see the header note on `ask()`).
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
-- `go`/`goo` mirror opencode.nvim's own recommended keymaps; the `<leader>o*`
-- variants exist alongside them for which-key discoverability.
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

-- Session management. `session.close` isn't a server command (see header),
-- so "close" means closing the terminal running the session.
vim.keymap.set("n", "<leader>on", command("session.new"), { desc = "New Session" })
vim.keymap.set("n", "<leader>oc", function()
  term.close(state)
end, { desc = "Close Session" })

-- Terminal: `opencode --port` in a right split (see `open()`/`toggle()`).
vim.keymap.set("n", "<leader>ot", toggle, { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>oq", function()
  term.close(state)
end, { desc = "Stop/Close Terminal" })

-- Action/prompt picker.
vim.keymap.set({ "n", "x" }, "<leader>oX", function()
  require("opencode").select()
end, { desc = "Execute Action…" })

-- Scroll the OpenCode terminal's message pane.
vim.keymap.set("n", "<leader>ou", command("session.half.page.up"), { desc = "Scroll Up" })
vim.keymap.set("n", "<leader>oj", command("session.half.page.down"), { desc = "Scroll Down" })
