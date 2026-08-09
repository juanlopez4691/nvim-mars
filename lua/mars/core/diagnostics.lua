-- Native diagnostics config: current-line-only virtual text approximates
-- the inline, powerline-style look of a plugin like tiny-inline-diagnostic
-- without one. Icons are gated behind vim.g.have_nerd_font (see AGENTS.md's
-- Icons section).

local severity = vim.diagnostic.severity

local icons = vim.g.have_nerd_font
    and {
      [severity.ERROR] = "󰅚 ",
      [severity.WARN] = "󰀪 ",
      [severity.INFO] = "󰋽 ",
      [severity.HINT] = "󰌶 ",
    }
  or {
    [severity.ERROR] = "E ",
    [severity.WARN] = "W ",
    [severity.INFO] = "I ",
    [severity.HINT] = "H ",
  }

vim.diagnostic.config({
  underline = true,
  severity_sort = true,
  signs = { text = icons },
  virtual_text = {
    current_line = true,
    spacing = 2,
    source = "if_many",
    prefix = function(diagnostic)
      return icons[diagnostic.severity]
    end,
  },
  float = {
    border = require("mars.ui.borders").style(),
    source = "if_many",
  },
})

-- Diagnostics list: quickfix for workspace-wide diagnostics, location list
-- for the current buffer, plus errors-only variants of each. Opens the
-- resulting window itself so there's no extra `:copen`/`:lopen` step.

--- Populates and opens the quickfix list with every diagnostic in the
--- workspace, optionally restricted to a minimum severity. Relies on
--- `setqflist`'s own `open` option rather than a separate `:copen`, since
--- issuing that after the fact can target the just-opened list window
--- itself instead of the window that owns it.
---@param opts? { severity?: integer }
local function workspace_diagnostics(opts)
  vim.diagnostic.setqflist(vim.tbl_extend("force", { open = true }, opts or {}))
end

--- Populates and opens the current window's location list with the current
--- buffer's diagnostics, optionally restricted to a minimum severity. See
--- `workspace_diagnostics` for why `open` is passed instead of `:lopen`.
---@param opts? { severity?: integer }
local function buffer_diagnostics(opts)
  vim.diagnostic.setloclist(vim.tbl_extend("force", { open = true }, opts or {}))
end

vim.api.nvim_create_user_command("MarsDiagnosticsWorkspace", function()
  workspace_diagnostics()
end, { desc = "Send workspace diagnostics to the quickfix list" })

vim.api.nvim_create_user_command("MarsDiagnosticsWorkspaceErrors", function()
  workspace_diagnostics({ severity = severity.ERROR })
end, { desc = "Send workspace error diagnostics to the quickfix list" })

vim.api.nvim_create_user_command("MarsDiagnosticsBuffer", function()
  buffer_diagnostics()
end, { desc = "Send buffer diagnostics to the location list" })

vim.api.nvim_create_user_command("MarsDiagnosticsBufferErrors", function()
  buffer_diagnostics({ severity = severity.ERROR })
end, { desc = "Send buffer error diagnostics to the location list" })

vim.keymap.set(
  "n",
  "<leader>cq",
  "<cmd>MarsDiagnosticsWorkspace<cr>",
  { silent = true, desc = "Code: workspace diagnostics to quickfix" }
)
vim.keymap.set(
  "n",
  "<leader>cQ",
  "<cmd>MarsDiagnosticsWorkspaceErrors<cr>",
  { silent = true, desc = "Code: workspace errors to quickfix" }
)
vim.keymap.set(
  "n",
  "<leader>cl",
  "<cmd>MarsDiagnosticsBuffer<cr>",
  { silent = true, desc = "Code: buffer diagnostics to location list" }
)
vim.keymap.set(
  "n",
  "<leader>cL",
  "<cmd>MarsDiagnosticsBufferErrors<cr>",
  { silent = true, desc = "Code: buffer errors to location list" }
)
