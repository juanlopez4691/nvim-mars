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

--- Truncates `s` to at most `width` display columns (walking characters,
--- not bytes, so multi-byte glyphs aren't split mid-character), appending
--- an ellipsis when it doesn't already fit.
---@param s string
---@param width integer
---@return string
local function truncate_to_width(s, width)
  if width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(s) <= width then
    return s
  end
  local ellipsis = "…"
  local budget = width - vim.fn.strdisplaywidth(ellipsis)
  if budget <= 0 then
    return ellipsis
  end
  local last_fit = ""
  for i = 1, vim.fn.strchars(s) do
    local candidate = vim.fn.strcharpart(s, 0, i)
    if vim.fn.strdisplaywidth(candidate) > budget then
      break
    end
    last_fit = candidate
  end
  return last_fit .. ellipsis
end

--- The text-display width of the first window currently showing `bufnr`
--- (excluding sign/number/fold columns), or nil if none is visible. Chips
--- are buffer-scoped extmarks shared by every window on that buffer, so
--- this only optimizes for one of them; the same documented trade-off
--- lua/mars/ui/indent.lua's scope highlighting makes for split windows.
---@param bufnr integer
---@return integer?
local function window_text_width(bufnr)
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return nil
  end
  local info = vim.fn.getwininfo(win)[1]
  return vim.api.nvim_win_get_width(win) - (info and info.textoff or 0)
end

--- Draws one chip extmark at the end of `lnum` (0-indexed): a two-space gap,
--- the arrow, then the icon and message sharing the chip background, a
--- single line, always. Wrapping this onto extra lines (tried and reverted)
--- pushes the rest of the buffer down by the wrapped height and stops
--- looking like a compact chip at all; a message too long for the room
--- left on `lnum` is truncated with an ellipsis instead, same as any
--- other overflowing UI text in this config (e.g. lua/mars/ui/notify.lua).
---@param bufnr integer
---@param lnum integer
---@param diag vim.Diagnostic
---@param text_width integer?
local function render_chip(bufnr, lnum, diag, text_width)
  local hl = CHIP_HL[diag.severity]
  local arrow_hl = ARROW_HL[diag.severity]
  if not (hl and arrow_hl) then
    return
  end
  local icon = diagnostic_icons()[diag.severity] or ""
  local arrow = diagnostic_arrow()
  local message = diag.message:gsub("\r", ""):gsub("\n", "  ")

  if text_width then
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
    -- Fixed-width parts: the 2-space gap, the arrow, and one padding space
    -- on each side of icon+message (see the virt_text chunks below).
    local fixed = 2 + vim.fn.strdisplaywidth(arrow) + 2 + vim.fn.strdisplaywidth(icon)
    local available = text_width - vim.fn.strdisplaywidth(line) - fixed
    message = truncate_to_width(message, available)
    if message == "" then
      return
    end
  end

  pcall(vim.api.nvim_buf_set_extmark, bufnr, CHIP_NAMESPACE, lnum, -1, {
    virt_text = {
      { "  " },
      { arrow, arrow_hl },
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
  local text_width = window_text_width(bufnr)
  for lnum, diag in pairs(worst_by_line) do
    render_chip(bufnr, lnum, diag, text_width)
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

-- Re-truncate affected buffers' chips when a window is resized (split
-- opened/closed, manual resize, ...); otherwise a chip sized for the old
-- width stays stale until its buffer's diagnostics next change.
vim.api.nvim_create_autocmd("WinResized", {
  group = augroup,
  callback = function()
    for _, win in ipairs(vim.v.event.windows or {}) do
      if vim.api.nvim_win_is_valid(win) then
        refresh_chips(vim.api.nvim_win_get_buf(win))
      end
    end
  end,
})

-- Diagnostics list: quickfix for workspace-wide diagnostics, location list
-- for the current buffer, plus errors-only variants of each. Opens the
-- resulting window itself so there's no extra `:copen`/`:lopen` step.

local M = {}

local QUICKFIX_TYPE_NAMES = { E = "error", W = "warn", I = "info", N = "note" }

--- 'quickfixtextfunc' implementation: shortens the file path (relative to
--- cwd when the file is under it, absolute otherwise; the same technique
--- :help quickfix-window-function itself recommends) instead of Neovim's
--- own default, which always shows the full path and crowds out the
--- message entirely on a deeply nested project path.
---@param info { quickfix: integer, winid: integer, id: integer, start_idx: integer, end_idx: integer }
---@return string[]
function M.quickfix_text(info)
  local items = info.quickfix == 1 and vim.fn.getqflist({ id = info.id, items = 1 }).items
    or vim.fn.getloclist(info.winid, { id = info.id, items = 1 }).items

  local lines = {}
  for i = info.start_idx, info.end_idx do
    local item = items[i]
    local fname = item.bufnr > 0 and vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":p:.") or ""
    local pos = ("%d col %d"):format(item.lnum, item.col)
    if item.end_col and item.end_col > item.col then
      pos = pos .. "-" .. item.end_col
    end
    local kind = QUICKFIX_TYPE_NAMES[item.type] or ""
    lines[#lines + 1] = ("%s|%s %s| %s"):format(fname, pos, kind, (item.text:gsub("\n", " ")))
  end
  return lines
end

vim.o.quickfixtextfunc = "v:lua.require'mars.core.diagnostics'.quickfix_text"

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

return M
