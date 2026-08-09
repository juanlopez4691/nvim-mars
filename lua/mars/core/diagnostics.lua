-- Native diagnostics config: current-line-only virtual text approximates
-- the inline, powerline-style look of a plugin like tiny-inline-diagnostic
-- without one. Icons fall back in three tiers: Nerd Font glyphs
-- (vim.g.have_nerd_font opt-in, see AGENTS.md's Icons section), Unicode
-- symbols (the default), or plain ASCII letters (vim.g.mars_ascii_diagnostics
-- opt-in, for terminals/log viewers that don't render Unicode reliably;
-- Neovim can't detect that any more than it can detect a Nerd Font, hence
-- another manual opt-in rather than a runtime check).

local severity = vim.diagnostic.severity

local nerd_font_icons = {
  [severity.ERROR] = "󰅚 ",
  [severity.WARN] = "󰀪 ",
  [severity.INFO] = "󰋽 ",
  [severity.HINT] = "󰌶 ",
}
local unicode_icons = {
  [severity.ERROR] = "✖ ",
  [severity.WARN] = "▲ ",
  [severity.INFO] = "● ",
  [severity.HINT] = "➤ ",
}
local ascii_icons = {
  [severity.ERROR] = "E ",
  [severity.WARN] = "W ",
  [severity.INFO] = "I ",
  [severity.HINT] = "H ",
}

--- Picks the icon table for the current render. Read at call time, not
--- cached, since `vim.g.have_nerd_font`/`vim.g.mars_ascii_diagnostics` are
--- set by `lua/mars/local.lua`, which loads after this module (see
--- AGENTS.md's Icons section).
---@return table<integer, string>
local function diagnostic_icons()
  if vim.g.have_nerd_font then
    return nerd_font_icons
  end
  if vim.g.mars_ascii_diagnostics then
    return ascii_icons
  end
  return unicode_icons
end

--- (Re-)applies the diagnostic config using the current icon tier.
--- `signs.text` is a plain table, not a per-render callback like
--- `virtual_text.prefix` below, so picking up a Nerd Font opt-in in the
--- sign column needs this re-run after local.lua has loaded, not just a
--- lazy read inside a callback.
local function apply()
  vim.diagnostic.config({
    underline = true,
    severity_sort = true,
    signs = { text = diagnostic_icons() },
    virtual_text = {
      current_line = true,
      spacing = 2,
      source = "if_many",
      prefix = function(diagnostic)
        return diagnostic_icons()[diagnostic.severity]
      end,
    },
    float = {
      border = require("mars.ui.borders").style(),
      source = "if_many",
    },
  })
end

apply()

-- Re-apply once more after lua/mars/local.lua (loaded last, see init.lua)
-- has had a chance to set vim.g.have_nerd_font, so the sign column picks up
-- an opt-in that wasn't visible yet at this module's own load time.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("mars_diagnostics_icons", { clear = true }),
  callback = apply,
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
