-- Native diagnostics config: always-on inline diagnostic "chips" approximate
-- the look of a plugin like tiny-inline-diagnostic without one, including a
-- soft background behind the message and a pointed leading arrow. Neovim's
-- built-in virtual_text renderer can't do the two-tone arrow (confirmed by
-- reading vim/diagnostic.lua's _get_virt_text_chunks: each diagnostic's
-- prefix+message share exactly one highlight group, so a wedge painted in
-- the chip's own color sitting on the plain editor background needs its own,
-- separate group). So virtual_text is turned off entirely below, and this
-- module draws its own extmarks on DiagnosticChanged instead, using only
-- public APIs (vim.diagnostic.get(), nvim_buf_set_extmark); no dependency
-- on Neovim's private rendering internals. Icons fall back in three tiers:
-- Nerd Font glyphs (vim.g.have_nerd_font opt-in, see AGENTS.md's Icons
-- section), Unicode symbols (the default), or plain ASCII letters
-- (vim.g.mars_ascii_diagnostics opt-in, for terminals/log viewers that don't
-- render Unicode reliably; Neovim can't detect that any more than it can
-- detect a Nerd Font, hence another manual opt-in rather than a runtime
-- check).
--
-- Scope-down: a line with more than one diagnostic only shows a chip for
-- the most severe one (matching severity_sort), not one chip per
-- diagnostic; the reference plugin stacks all of them side by side, which
-- would need tracking per-line diagnostic counts/widths this module doesn't.

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

-- Leading arrow before the icon, pointing from the chip back at the
-- offending code. The Nerd Font tier uses the dedicated powerline "hard
-- divider" glyph (U+E0B2) tiny-inline-diagnostic.nvim itself uses for this
-- exact two-tone separator technique; general-purpose Unicode shapes like
-- ◀ aren't built for it and can render with inconsistent font coverage/color
-- fidelity depending on the terminal's fallback font.
local NERD_FONT_ARROW = vim.fn.nr2char(0xe0b2)
local UNICODE_ARROW = "◀"
local ASCII_ARROW = "<"

--- Picks the leading arrow glyph for the current render, mirroring
--- diagnostic_icons()'s three tiers.
---@return string
local function diagnostic_arrow()
  if vim.g.have_nerd_font then
    return NERD_FONT_ARROW
  end
  if vim.g.mars_ascii_diagnostics then
    return ASCII_ARROW
  end
  return UNICODE_ARROW
end

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

-- Highlight group names for the chip body and its leading arrow, per
-- severity. Names only; apply_chip_highlights() below fills in their
-- actual colors, since those depend on whichever colorscheme is active.
local CHIP_HL = {
  [severity.ERROR] = "DiagnosticVirtualTextError",
  [severity.WARN] = "DiagnosticVirtualTextWarn",
  [severity.INFO] = "DiagnosticVirtualTextInfo",
  [severity.HINT] = "DiagnosticVirtualTextHint",
}
local ARROW_HL = {
  [severity.ERROR] = "MarsDiagnosticArrowError",
  [severity.WARN] = "MarsDiagnosticArrowWarn",
  [severity.INFO] = "MarsDiagnosticArrowInfo",
  [severity.HINT] = "MarsDiagnosticArrowHint",
}

--- Mixes `ratio` of `fg` (0xRRGGBB) into `bg` (0xRRGGBB).
---@param fg integer
---@param bg integer
---@param ratio number 0 (pure bg) to 1 (pure fg)
---@return integer
local function blend(fg, bg, ratio)
  local function channel(color, divisor)
    return math.floor(color / divisor) % 256
  end
  local function mix(f, b)
    return math.floor(f * ratio + b * (1 - ratio) + 0.5)
  end
  local r = mix(channel(fg, 65536), channel(bg, 65536))
  local g = mix(channel(fg, 256), channel(bg, 256))
  local b = mix(channel(fg, 1), channel(bg, 1))
  return r * 65536 + g * 256 + b
end

-- How much of each severity color to mix into the editor background for the
-- chip: too high looks like a solid banner, too low is indistinguishable
-- from a plain, unstyled background.
local CHIP_BLEND_RATIO = 0.18

--- (Re-)derives the chip and arrow highlight groups from whichever
--- colorscheme is currently active. The chip is `severity fg` on a blend of
--- that same color into 'Normal's background; the arrow is painted *in* the
--- chip's background color, but sitting on the plain editor background, so
--- it reads as the chip's own pointed left edge rather than a separate
--- glyph. Read at call time, not cached; see the module header.
local function apply_chip_highlights()
  local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
  if not normal_bg then
    return
  end
  local sources = {
    [severity.ERROR] = "DiagnosticError",
    [severity.WARN] = "DiagnosticWarn",
    [severity.INFO] = "DiagnosticInfo",
    [severity.HINT] = "DiagnosticHint",
  }
  for sev, source in pairs(sources) do
    local fg = vim.api.nvim_get_hl(0, { name = source }).fg
    if fg then
      local chip_bg = blend(fg, normal_bg, CHIP_BLEND_RATIO)
      vim.api.nvim_set_hl(0, CHIP_HL[sev], { fg = fg, bg = chip_bg, italic = true })
      vim.api.nvim_set_hl(0, ARROW_HL[sev], { fg = chip_bg, bg = normal_bg })
    end
  end
end

local CHIP_NAMESPACE = vim.api.nvim_create_namespace("mars_diagnostics_chip")

--- Draws one chip extmark at the end of `lnum` (0-indexed): a two-space gap,
--- the arrow, then the icon and message sharing the chip background.
---@param bufnr integer
---@param lnum integer
---@param diag vim.Diagnostic
local function render_chip(bufnr, lnum, diag)
  local hl = CHIP_HL[diag.severity]
  local arrow_hl = ARROW_HL[diag.severity]
  if not (hl and arrow_hl) then
    return
  end
  local icon = diagnostic_icons()[diag.severity] or ""
  local message = diag.message:gsub("\r", ""):gsub("\n", "  ")
  pcall(vim.api.nvim_buf_set_extmark, bufnr, CHIP_NAMESPACE, lnum, -1, {
    virt_text = {
      { "  " },
      { diagnostic_arrow(), arrow_hl },
      { " " .. icon .. message .. " ", hl },
    },
    virt_text_pos = "eol",
    priority = 200,
  })
end

--- Redraws every diagnostic chip for `bufnr` from scratch: clears the
--- namespace, then re-renders one chip per line showing its most severe
--- diagnostic (lower `severity` number wins; ERROR is 1).
---@param bufnr integer
local function refresh_chips(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, CHIP_NAMESPACE, 0, -1)
  local worst_by_line = {}
  for _, diag in ipairs(vim.diagnostic.get(bufnr)) do
    local current = worst_by_line[diag.lnum]
    if not current or diag.severity < current.severity then
      worst_by_line[diag.lnum] = diag
    end
  end
  for lnum, diag in pairs(worst_by_line) do
    render_chip(bufnr, lnum, diag)
  end
end

--- (Re-)applies the diagnostic config using the current icon tier, the chip
--- highlight overrides above, and a chip redraw for every open buffer.
--- `signs.text` is a plain table, not a per-render callback, so picking up
--- a Nerd Font opt-in in the sign column needs this re-run after local.lua
--- has loaded, not just a lazy read inside a callback; the chip colors need
--- the same re-run whenever the colorscheme (re)loads.
local function apply()
  apply_chip_highlights()
  vim.diagnostic.config({
    underline = true,
    severity_sort = true,
    signs = { text = diagnostic_icons() },
    virtual_text = false,
    float = {
      border = require("mars.ui.borders").style(),
      source = "if_many",
    },
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    refresh_chips(buf)
  end
end

apply()

local augroup = vim.api.nvim_create_augroup("mars_diagnostics_icons", { clear = true })

-- Re-apply once more after lua/mars/local.lua (loaded last, see init.lua)
-- has had a chance to set vim.g.have_nerd_font, so the sign column picks up
-- an opt-in that wasn't visible yet at this module's own load time.
vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup,
  callback = apply,
})

-- Re-apply on every colorscheme (re)load, including lua/mars/local.lua
-- switching away from the default colorscheme, so the chip colors track
-- whichever palette is actually active instead of freezing to startup's.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = apply,
})

-- Redraw a buffer's chips whenever its diagnostics change (LSP publish,
-- vim.diagnostic.set/reset, etc.); this is what actually keeps the chips
-- in sync, since virtual_text is off and nothing else draws them.
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = augroup,
  callback = function(ev)
    refresh_chips(ev.buf)
  end,
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
