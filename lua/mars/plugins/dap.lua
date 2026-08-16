-- nvim-dap + nvim-dap-ui + nvim-dap-virtual-text + mason-nvim-dap: the
-- debugging stack. Per-language adapters/configurations and debugging keymaps
-- are separate follow-up tickets (NEO-45, NEO-46, NEO-47).
--
-- nvim-nio below is nvim-dap-ui's own hard runtime dependency (async UI
-- primitives), pulled in solely to satisfy its `require()`s.

require("mars.pack").add({
  { src = "https://github.com/mfussenegger/nvim-dap" },
  { src = "https://github.com/nvim-neotest/nvim-nio" },
  { src = "https://github.com/rcarriga/nvim-dap-ui" },
  { src = "https://github.com/theHamsta/nvim-dap-virtual-text" },
  { src = "https://github.com/jay-babu/mason-nvim-dap.nvim" },
})

--- Defines nvim-dap's gutter signs. Icons gated on `vim.g.have_nerd_font`,
--- resolved at call time rather than memoized at module load.
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

--- Sets up the whole stack: gutter signs, dap-ui, dap-virtual-text, and
--- mason-nvim-dap, plus the listeners that open/close dap-ui alongside a
--- debug session's lifecycle.
---@return nil
local function setup_dap()
  define_signs()

  local dap = require("dap")
  local dapui = require("dapui")

  dapui.setup()
  require("nvim-dap-virtual-text").setup()

  require("mason-nvim-dap").setup({
    -- Adapter ensure-install is a per-language decision left to follow-ups.
    ensure_installed = {},
    automatic_installation = true,
    -- selene: allow(mixed_table)
    -- mason-nvim-dap's API: unkeyed default handler plus keyed per-source overrides.
    handlers = {
      function(config)
        require("mason-nvim-dap").default_setup(config)
      end,
      -- The PHP adapter is installed via Mason's `php-debug-adapter` package
      -- directly (see mason.lua), not mason-nvim-dap's auto-config, so this
      -- handler is a no-op.
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
    -- One tick past VimEnter so mason.lua's own VimEnter hook has already
    -- run: mason.nvim needs setup() before anything requires "mason-registry"
    -- (which mason-nvim-dap's setup() does internally), regardless of file
    -- load order.
    vim.schedule(setup_dap)
  end,
})
