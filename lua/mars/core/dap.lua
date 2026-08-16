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

--- Returns a callback that calls `dap[fn_name]()` with no arguments.
---@param fn_name string
---@return fun()
local function safe_dap_call(fn_name)
  return function()
    local dap = require_dap("dap")
    if dap then
      dap[fn_name]()
    end
  end
end

--- Same as `safe_dap_call`, but for nvim-dap-ui.
---@param fn_name string
---@return fun()
local function safe_dapui_call(fn_name)
  return function()
    local dapui = require_dap("dapui")
    if dapui then
      dapui[fn_name]()
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
  safe_dapui_call("close")()
  safe_dap_call("terminate")()
end

--- `before` hook for `dap.continue()`, prompting for launch args
--- pre-filled from the config. A `get_args`-style hook, minus the
--- java-specific string-args branch (no java adapter here).
---@param config table
---@return table
local function get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
  local args_str = type(args) == "table" and table.concat(args, " ") or args

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

bind({ "<leader>db", "<F9>" }, safe_dap_call("toggle_breakpoint"), "Debug: toggle breakpoint")
bind({ "<leader>dB", "<F21>", "<S-F9>" }, set_conditional_breakpoint, "Debug: conditional breakpoint")
bind({ "<leader>dc", "<F5>" }, safe_dap_call("continue"), "Debug: continue")
bind({ "<leader>dC", "<F17>", "<S-F5>" }, safe_dap_call("run_to_cursor"), "Debug: run to cursor")
bind({ "<leader>di", "<F11>" }, safe_dap_call("step_into"), "Debug: step into")
bind({ "<leader>do", "<F23>", "<S-F11>" }, safe_dap_call("step_out"), "Debug: step out")
bind({ "<leader>dO", "<F10>" }, safe_dap_call("step_over"), "Debug: step over")
bind({ "<leader>dj", "<F6>" }, safe_dap_call("down"), "Debug: down stack frame")
bind({ "<leader>dk", "<F18>", "<S-F6>" }, safe_dap_call("up"), "Debug: up stack frame")
bind({ "<leader>dl", "<F29>", "<C-F5>" }, safe_dap_call("run_last"), "Debug: run last")
bind({ "<leader>dP", "<F7>" }, safe_dap_call("pause"), "Debug: pause")
bind({ "<leader>dt", "<F8>" }, terminate, "Debug: terminate")
bind({ "<leader>de", "<F12>" }, safe_dapui_call("eval"), "Debug: eval under cursor")
bind({ "<leader>da" }, run_with_args, "Debug: run with args")
bind({ "<leader>dr" }, toggle_repl, "Debug: toggle REPL")
bind({ "<leader>ds" }, safe_dap_call("session"), "Debug: session")
bind({ "<leader>du" }, safe_dapui_call("toggle"), "Debug: toggle dap-ui")
bind({ "<leader>dw" }, widget_hover, "Debug: widget hover")
