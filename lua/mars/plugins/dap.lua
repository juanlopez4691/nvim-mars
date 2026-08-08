-- nvim-dap + nvim-dap-ui + nvim-dap-virtual-text + mason-nvim-dap: the
-- debugging stack (see AGENTS.md's approved exception list; debugging is
-- explicitly the "complex, worth a plugin" case). This file only wires up
-- the stack itself: gutter signs, dap-ui's auto show/hide alongside a debug
-- session, virtual text, and Mason-driven adapter installation. Per-language
-- adapters/configurations and debugging keymaps are separate follow-up
-- tickets (NEO-45, NEO-46, NEO-47) building on top of this.
--
-- nvim-nio below is nvim-dap-ui's own hard runtime dependency (async UI
-- primitives), pulled in solely to satisfy its `require()`s; same
-- treatment as nui.nvim/plenary.nvim/nvim-nio in lua/mars/plugins/laravel.lua.

require("mars.pack").add({
  { src = "https://github.com/mfussenegger/nvim-dap" },
  { src = "https://github.com/nvim-neotest/nvim-nio" },
  { src = "https://github.com/rcarriga/nvim-dap-ui" },
  { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
  { src = "https://github.com/jay-babu/mason-nvim-dap.nvim" },
})

--- Defines nvim-dap's gutter signs. Icons are gated behind
--- `vim.g.have_nerd_font` (see AGENTS.md's Icons section) and resolved here,
--- at call time, rather than memoized at module load.
---@return nil
local function define_signs()
  local nerd_font = vim.g.have_nerd_font

  local signs = {
    DapBreakpoint = { text = nerd_font and "" or "B", texthl = "DiagnosticError" },
    DapBreakpointCondition = { text = nerd_font and "" or "C", texthl = "DiagnosticWarn" },
    DapLogPoint = { text = nerd_font and "" or "L", texthl = "DiagnosticInfo" },
    DapBreakpointRejected = { text = nerd_font and "" or "R", texthl = "DiagnosticError" },
    DapStopped = {
      text = nerd_font and "" or ">",
      texthl = "DiagnosticWarn",
      linehl = "Visual",
      numhl = "DiagnosticWarn",
    },
  }

  for name, sign in pairs(signs) do
    vim.fn.sign_define(name, sign)
  end
end

local dap_ready = false

--- Sets up the whole stack exactly once: gutter signs, dap-ui, dap-virtual-
--- text, and mason-nvim-dap, plus the listeners that open/close dap-ui
--- alongside a debug session's lifecycle (in place of a manual toggle
--- keymap, which is out of scope here; see the follow-up keymap ticket).
--- Safe to call repeatedly.
---@return nil
local function setup_dap()
  if dap_ready then
    return
  end
  dap_ready = true

  define_signs()

  local dap = require("dap")
  local dapui = require("dapui")

  dapui.setup()
  require("nvim-dap-virtual-text").setup()

  require("mason-nvim-dap").setup({
    -- Left empty deliberately: which adapters to ensure-install is a
    -- per-language decision for the follow-up tickets to make.
    ensure_installed = {},
    automatic_installation = true,
    -- selene: allow(mixed_table)
    -- mason-nvim-dap's own API: an unkeyed default handler plus keyed
    -- per-source overrides in the same table.
    handlers = {
      function(config)
        require("mason-nvim-dap").default_setup(config)
      end,
      -- The PHP debug adapter is installed via Mason's `php-debug-adapter`
      -- package directly (see lua/mars/plugins/mason.lua), not through
      -- mason-nvim-dap's auto-config, so its handler is a deliberate no-op.
      php = function() end,
    },
  })

  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end
end

require("mars.pack").on({
  event = "VimEnter",
  config = function()
    -- Deferred one more tick past VimEnter so mason.lua's own VimEnter
    -- hook (which calls `require("mason").setup()`) has already run
    -- first, regardless of the two files' relative load order: mason.nvim
    -- requires its `setup()` to run before anything requires
    -- "mason-registry" (which mason-nvim-dap's `setup()` does internally).
    vim.schedule(setup_dap)
  end,
})
