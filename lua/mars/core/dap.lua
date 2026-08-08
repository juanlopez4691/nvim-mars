-- DAP keymaps: F-key and <leader>d* bindings that drive an nvim-dap session
-- once one is running (see lua/mars/plugins/dap.lua, NEO-44, for the stack
-- itself: nvim-dap/nvim-dap-ui/nvim-dap-virtual-text/mason-nvim-dap,
-- lazy-loaded on VimEnter).
-- `<leader>d` is already reserved as the "Debug" which-key group in
-- lua/mars/plugins/which-key.lua.
--
-- Shifted/Ctrl F-key variants: many terminals don't report Shift/Ctrl held
-- with a function key as `<S-F5>`/`<C-F5>`; they send a distinct extended
-- keycode instead, following a long-standing xterm/tmux convention:
-- Shift-Fn arrives as Fn+12 (F13..F24) and Ctrl-Fn as Fn+24 (F25..F36).
-- These extended codes surface as `<F17>` for Shift-F5, `<F21>`
-- for Shift-F9, `<F23>` for Shift-F11, `<F18>` for Shift-F6, `<F29>` for
-- Ctrl-F5, instead of binding `<S-F5>`/`<C-F5>` directly. A terminal or
-- multiplexer that *does* forward the modifier notation natively would get
-- no keymap at all from the extended keycode alone, so every shifted/ctrl
-- action below binds both forms; whichever one a given terminal reports,
-- the keymap fires.

--- Returns a callback that pcall-guards `require("dap")`, then calls
--- `dap[fn_name]()` with no arguments. Warns and no-ops instead of erroring
--- if nvim-dap isn't available (e.g. not finished loading yet, or the
--- plugin failed to install).
---@param fn_name string
---@return fun()
local function safe_dap_call(fn_name)
  return function()
    local ok, dap = pcall(require, "dap")
    if not ok then
      vim.notify("nvim-dap is not available", vim.log.levels.WARN)
      return
    end
    dap[fn_name]()
  end
end

--- Same as `safe_dap_call`, but for nvim-dap-ui.
---@param fn_name string
---@return fun()
local function safe_dapui_call(fn_name)
  return function()
    local ok, dapui = pcall(require, "dapui")
    if not ok then
      vim.notify("nvim-dap-ui is not available", vim.log.levels.WARN)
      return
    end
    dapui[fn_name]()
  end
end

--- Prompts for a breakpoint condition and sets a conditional breakpoint at
--- the current line. Pcall-guarded the same way as `safe_dap_call`.
---@return nil
local function set_conditional_breakpoint()
  local ok, dap = pcall(require, "dap")
  if not ok then
    vim.notify("nvim-dap is not available", vim.log.levels.WARN)
    return
  end
  dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end

--- Closes dap-ui, then terminates the current debug session. Each half
--- goes through its own safe wrapper, so a missing/broken dap-ui doesn't
--- stop the `dap.terminate()` half from still running.
---@return nil
local function terminate()
  safe_dapui_call("close")()
  safe_dap_call("terminate")()
end

--- Binds normal-mode `rhs` to every lhs in `lhs_list` with the same
--- description, used below so one action reachable via its `<leader>d*`
--- mnemonic and one or more F-key forms (plain, extended-numeric, and/or
--- `<S-Fn>`/`<C-Fn>`) doesn't repeat the `vim.keymap.set` boilerplate per
--- key, mirroring the multi-lhs pattern in lua/mars/core/splits.lua.
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
