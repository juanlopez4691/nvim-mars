-- jbyuki/one-small-step-for-vimkind ("osv"): nvim-dap adapter for debugging
-- Neovim's own embedded Lua. Lazy-loaded on the `lua` filetype.
--
-- Wiring follows osv's own docs: `run_this()` is gone from the currently
-- pinned osv release (only `M.launch()` does).
-- `require("osv").launch(...)` starts the debuggee's server from a keymap,
-- which lives with the rest of the debugging keymaps (see dap.lua).

require("mars.pack").add({
  { src = "https://github.com/jbyuki/one-small-step-for-vimkind" },
})

--- Registers the `nlua` dap adapter and this file type's dap
--- configurations. Safe to call repeatedly.
---@return nil
local function setup()
  local dap = require("dap")

  --- Connects to an osv server (started via `require("osv").launch(...)`
  --- in the debuggee) over TCP.
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
