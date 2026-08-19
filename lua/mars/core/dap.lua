-- DAP keymaps driving nvim-dap (see lua/mars/plugins/dap.lua). `<leader>d`
-- is the "Debug" which-key group
-- (lua/mars/plugins/which-key.lua).
--
-- Shift/Ctrl F-key variants: terminals typically send Fn+12 (Shift) and
-- Fn+24 (Ctrl) extended keycodes rather than `<S-Fn>`/`<C-Fn>`, so each
-- action binds both forms; whichever a given terminal reports, the keymap
-- fires.

--- Pcall-guards `require(mod)`, returning nil (with a warning) when
--- nvim-dap isn't available.
---@param mod string
---@return table?
local function require_dap(mod)
  local ok, dap = pcall(require, mod)
  if not ok then
    vim.notify("nvim-dap is not available", vim.log.levels.WARN)
    return nil
  end
  return dap
end

--- Returns a callback that calls `mod[fn_name]()` with no arguments, guarding
--- against the module not being available (nvim-dap / nvim-dap-ui).
---@param mod string
---@param fn_name string
---@return fun()
local function safe_call(mod, fn_name)
  return function()
    local target = require_dap(mod)
    if target then
      target[fn_name]()
    end
  end
end

--- Prompts for a breakpoint condition and sets it at the current line.
---@return nil
local function set_conditional_breakpoint()
  local dap = require_dap("dap")
  if dap then
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end
end

--- Closes dap-ui, then terminates the session; each half is independently
--- safe-wrapped so a broken dap-ui can't stop `dap.terminate()`.
---@return nil
local function terminate()
  safe_call("dapui", "close")()
  safe_call("dap", "terminate")()
end

--- `before` hook for `dap.continue()`, prompting for launch args
--- pre-filled from the config. A `get_args`-style hook, minus the
--- java-specific string-args branch (no java adapter here).
---@param config table
---@return table
local function get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
  local args_str = type(args) == "table" and table.concat(args, " ") or tostring(args)

  config = vim.deepcopy(config)
  config.args = function()
    local new_args = vim.fn.expand(vim.fn.input("Run with args: ", args_str))
    return require("dap.utils").splitstr(new_args)
  end
  return config
end

--- Continues (or starts) the session after prompting for args.
---@return nil
local function run_with_args()
  local dap = require_dap("dap")
  if dap then
    dap.continue({ before = get_args })
  end
end

--- Toggles nvim-dap's REPL window; `repl.toggle` isn't a top-level `dap.*`.
---@return nil
local function toggle_repl()
  local dap = require_dap("dap")
  if dap then
    dap.repl.toggle()
  end
end

--- Hover widget with debug info for the expression under the cursor.
---@return nil
local function widget_hover()
  local widgets = require_dap("dap.ui.widgets")
  if widgets then
    widgets.hover()
  end
end

--- Binds normal-mode `rhs` to every lhs in `lhs_list` with the same
--- description, so one action's multiple key forms share one keymap call.
---@param lhs_list string[]
---@param rhs fun()
---@param desc string
local function bind(lhs_list, rhs, desc)
  for _, lhs in ipairs(lhs_list) do
    vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
  end
end

bind({ "<leader>db", "<F9>" }, safe_call("dap", "toggle_breakpoint"), "Toggle Breakpoint")
bind({ "<leader>dB", "<F21>", "<S-F9>" }, set_conditional_breakpoint, "Conditional Breakpoint")
bind({ "<leader>dc", "<F5>" }, safe_call("dap", "continue"), "Run/Continue")
bind({ "<leader>dC", "<F17>", "<S-F5>" }, safe_call("dap", "run_to_cursor"), "Run to Cursor")
bind({ "<leader>di", "<F11>" }, safe_call("dap", "step_into"), "Step Into")
bind({ "<leader>do", "<F23>", "<S-F11>" }, safe_call("dap", "step_out"), "Step Out")
bind({ "<leader>dO", "<F10>" }, safe_call("dap", "step_over"), "Step Over")
bind({ "<leader>dj", "<F6>" }, safe_call("dap", "down"), "Down Stack Frame")
bind({ "<leader>dk", "<F18>", "<S-F6>" }, safe_call("dap", "up"), "Up Stack Frame")
bind({ "<leader>dl", "<F29>", "<C-F5>" }, safe_call("dap", "run_last"), "Run Last")
bind({ "<leader>dP", "<F7>" }, safe_call("dap", "pause"), "Pause")
bind({ "<leader>dt", "<F8>" }, terminate, "Terminate")
bind({ "<leader>de", "<F12>" }, safe_call("dapui", "eval"), "Eval Under Cursor")
bind({ "<leader>da" }, run_with_args, "Run with Args")
bind({ "<leader>dr" }, toggle_repl, "Toggle REPL")
bind({ "<leader>ds" }, safe_call("dap", "session"), "Session")
bind({ "<leader>du" }, safe_call("dapui", "toggle"), "Toggle dap-ui")
bind({ "<leader>dw" }, widget_hover, "Widget Hover")
