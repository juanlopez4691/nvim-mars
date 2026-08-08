-- jbyuki/one-small-step-for-vimkind ("osv"): the standard nvim-dap adapter
-- for debugging Neovim's own embedded Lua, useful for stepping through
-- Mars's own config code. This is a natural extension of the already-
-- approved nvim-dap exception in AGENTS.md (see lua/mars/plugins/dap.lua),
-- not a separate plugin decision: it plugs `nlua` into the same `dap`
-- instance that stack sets up, but ships as its own package, so it needs
-- its own vim.pack entry here. Lazy-loaded on the `lua` filetype since it's
-- only relevant when editing Lua.
--
-- Adapter/configuration wiring follows osv's own documented nvim-dap
-- integration (README's "Configuration" section): the `start_neovim` branch
-- calls `require("osv").run_this()`, which no longer exists in the currently
-- pinned osv release (only `M.launch()` does); porting it verbatim would
-- wire up a config entry that errors on use. `require("osv").launch(...)`
-- (bound to a keymap) is how a debuggee starts its own osv server; that
-- keymap is out of scope here (see dap.lua's follow-up-tickets note) and
-- belongs with the rest of the debugging keymaps.

require("mars.pack").add({
  { src = "https://github.com/jbyuki/one-small-step-for-vimkind" },
})

--- Registers the `nlua` dap adapter and this file type's dap
--- configurations. Safe to call repeatedly.
---@return nil
local function setup()
  local dap = require("dap")

  --- Standard osv adapter wiring: connects to an osv server (started via
  --- `require("osv").launch(...)` in the debuggee) over TCP.
  ---@param callback fun(adapter: table)
  ---@param conf table
  dap.adapters.nlua = function(callback, conf)
    callback({ type = "server", host = conf.host or "127.0.0.1", port = conf.port or 8086 })
  end

  dap.configurations.lua = {
    {
      type = "nlua",
      request = "attach",
      name = "Attach to running Neovim instance",
      port = 8086,
    },
  }
end

require("mars.pack").on({
  ft = "lua",
  config = setup,
})
