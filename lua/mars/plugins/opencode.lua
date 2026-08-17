-- NickvanDyke/opencode.nvim: chat/agent integration with the OpenCode CLI,
-- the sole AI surface in this config. Everything lives under `<leader>o*`;
-- `<leader>a` is a separate reserved namespace and stays untouched here.
--
-- No `setup()` call: opencode.nvim reads `vim.g.opencode_opts` lazily on the
-- first `require()`, so the require()s inside the keymaps below stay the true
-- lazy-load point. `opencode_opts.server.start` launches `opencode --port`
-- in a right-side split through lua/mars/helpers/term.lua, the shared
-- terminal manager that also powers the generic `<leader>t` terminal,
-- lazygit, and scooter.
--
-- Adapted to the currently-tracked API (pack tracks the default branch, not
-- a pinned release): `ask()` takes only a `default` prefill; the old
-- `{ submit, focus }` opts are gone, so quick asks open an editable prompt;
-- `prompt()` submits immediately, but only when the text doesn't end in a
-- space (trailing space means "append, don't submit"), so the quick actions
-- below end in `:` instead; `@diff` is gone (`@diagnostics` replaces it,
-- so `<leader>od`); and `session.close` isn't a real command, so
-- `<leader>oc` closes the terminal itself. Terminal toggles stay normal-mode
-- only: with a space leader, a terminal-mode leader mapping delays every
-- literal space typed in a terminal buffer.

require("mars.pack").add({
  { src = "https://github.com/NickvanDyke/opencode.nvim" },
})

local term = require("mars.helpers.term")

--- Launch options for the `opencode --port` terminal (a right split).
--- `count` is pinned to 1 so `2<leader>o*` counts can't spawn a second
--- OpenCode instance behind the scenes.
---@return { cmd: string[], cwd: string, count: integer, win_config: table }
local function terminal_opts()
  return {
    cmd = { "opencode", "--port" },
    cwd = vim.fs.root(0, ".git") or vim.uv.cwd(),
    count = 1,
    win_config = {
      split = "right",
      win = -1,
      width = math.floor(vim.o.columns * 0.4),
    },
  }
end

---@return boolean
local function opencode_available()
  if vim.fn.executable("opencode") == 0 then
    vim.notify("opencode not found on PATH; install it to use OpenCode", vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Opens (or focuses) the terminal running `opencode --port` in a right
--- split. Doubles as `opencode_opts.server.start` and the prompt-submit
--- "show the chat" handler.
local function open()
  if not opencode_available() then
    return
  end
  term.open(terminal_opts())
end

--- Closes the terminal when it's the current window, otherwise opens/
--- focuses it, the usual toggle contract for a side-split terminal.
local function toggle()
  if not opencode_available() then
    return
  end
  term.toggle(terminal_opts())
end

--- Stops the `opencode --port` server by closing its terminal.
local function close()
  term.close(terminal_opts())
end

---@type opencode.Opts
vim.g.opencode_opts = {
  server = {
    start = function()
      -- Start `opencode --port` *hidden* (buffer + process, no window): the
      -- ask prompt runs while it comes up, and an empty terminal split shown
      -- under the blocking prompt just looks broken. The terminal is surfaced
      -- (focused) on `prompt.submit` and by `<leader>ot`.
      local opts = terminal_opts()
      opts.show = false
      term.open(opts)
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

-- Prompts: act on `@this` (range/selection, else cursor) immediately. No
-- trailing space; `prompt()` appends to the TUI input without submitting
-- when the text ends in a space (the "append" contract), so these end in
-- `:` instead.
vim.keymap.set({ "n", "x" }, "<leader>of", prompt("@this fix:"), { desc = "Fix" })
vim.keymap.set({ "n", "x" }, "<leader>oe", prompt("@this explain:"), { desc = "Explain" })
vim.keymap.set({ "n", "x" }, "<leader>or", prompt("@this review:"), { desc = "Review" })
vim.keymap.set({ "n", "x" }, "<leader>oo", prompt("@this optimize:"), { desc = "Optimize" })
vim.keymap.set({ "n", "x" }, "<leader>os", prompt("@this test:"), { desc = "Test" })
vim.keymap.set({ "n", "x" }, "<leader>oD", prompt("@this diagnose:"), { desc = "Diagnose" })

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
vim.keymap.set("n", "<leader>oc", close, { desc = "Close Session" })

-- When a prompt is submitted, bring the opencode terminal into view so the
-- chat (and its streaming response) is visible, the documented behavior for
-- a split-based `server.start` (README's `prompt.submit` → show autocmd).
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent:tui.command.execute",
  callback = function(args)
    if args.data.event.properties.command == "prompt.submit" then
      open()
    end
  end,
})

-- Terminal: `opencode --port` in a right split (see `open()`/`toggle()`).
vim.keymap.set("n", "<leader>ot", toggle, { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>oq", close, { desc = "Stop/Close Terminal" })

-- Action/prompt picker.
vim.keymap.set({ "n", "x" }, "<leader>oX", function()
  require("opencode").select()
end, { desc = "Execute Action…" })

-- Scroll the OpenCode terminal's message pane.
vim.keymap.set("n", "<leader>ou", command("session.half.page.up"), { desc = "Scroll Up" })
vim.keymap.set("n", "<leader>oj", command("session.half.page.down"), { desc = "Scroll Down" })
