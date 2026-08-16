-- Native diagnostics: inline "chips" approximate tiny-inline-diagnostic
-- without it. Neovim's virtual_text renderer can't do the two-tone arrow
-- (one highlight group per diagnostic), so virtual_text is off and this
-- draws its own extmarks on DiagnosticChanged with public APIs only.
-- Icons: Nerd Font glyphs (opt-in), Unicode (default), or ASCII (opt-in).
--
-- Scope-down: one chip per line showing only the most severe diagnostic.

local severity = vim.diagnostic.severity

local text = require("mars.text")

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

-- Leading arrow pointing back at the code. Nerd Font tier uses the powerline
-- hard-divider glyph (U+E0B2) for the two-tone separator; general Unicode
-- shapes have inconsistent font coverage.
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

--- Picks the icon table for the current render. Read at call time, since the
--- opt-ins live in local.lua which loads after this module.
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

-- Chip body and arrow highlight group names, per severity.
-- apply_chip_highlights() fills in the colors from the active colorscheme.
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

-- Fraction of severity color mixed into the background for the chip.
local CHIP_BLEND_RATIO = 0.18

--- (Re-)derives chip/arrow highlight groups from the active colorscheme:
--- the chip is severity fg on a blend into 'Normal' bg; the arrow is painted
--- in the chip's bg sitting on the editor bg, reading as the chip's left edge.
--- Read at call time, not cached (see the module header).
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

--- Text-display width of the first window showing `bufnr` (excluding sign/
--- number/fold columns), or nil if none is visible.
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

--- Draws one chip extmark at the end of `lnum`: a two-space gap, the arrow,
--- then icon+message sharing the chip background, always a single line;
--- long messages are truncated with an ellipsis.
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
    message = text.truncate_to_width(message, available, { ellipsis = true })
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

--- (Re-)applies the diagnostic config with the current icon tier, chip
--- highlights, and a chip redraw for every open buffer. Needs re-running
--- after local.lua loads (signs.text is a plain table, not a callback) and
--- on every colorscheme (re)load.
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

-- Re-apply after local.lua loads, so the sign column picks up a Nerd Font
-- opt-in that wasn't visible at this module's load time.
vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup,
  callback = apply,
})

-- Re-apply on every colorscheme (re)load so chip colors track the palette.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = apply,
})

-- Chips are the only renderer (virtual_text is off); redraw on change.
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = augroup,
  callback = function(ev)
    refresh_chips(ev.buf)
  end,
})

-- Re-truncate chips after a window resize; otherwise they stay sized stale.
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

-- Diagnostics list: quickfix for workspace diagnostics, location list for
-- the current buffer, plus errors-only variants of each.

local M = {}

local QUICKFIX_TYPE_NAMES = { E = "error", W = "warn", I = "info", N = "note" }

--- Shortens `path` to "./"-relative when it sits under the buffer's project
--- root (lua/mars/core/rootdir.lua). Unrelated paths stay absolute rather
--- than claim a false "./" relationship.
---@param bufnr integer
---@param path string absolute path
---@return string
local function short_path(bufnr, path)
  local root = require("mars.core.rootdir").get(bufnr)
  if vim.startswith(path, root .. "/") then
    return "./" .. path:sub(#root + 2)
  end
  return path
end

--- 'quickfixtextfunc' implementation shortening file paths so deeply nested
--- projects don't crowd out the message.
---@param info { quickfix: integer, winid: integer, id: integer, start_idx: integer, end_idx: integer }
---@return string[]
function M.quickfix_text(info)
  local items = info.quickfix == 1 and vim.fn.getqflist({ id = info.id, items = 1 }).items
    or vim.fn.getloclist(info.winid, { id = info.id, items = 1 }).items

  local lines = {}
  for i = info.start_idx, info.end_idx do
    local item = items[i]
    local fname = ""
    if item.bufnr > 0 then
      fname = short_path(item.bufnr, vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":p"))
    end
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

--- Populates and opens the quickfix list with workspace diagnostics,
--- optionally restricted to a severity. Passes `open` to setqflist; a
--- separate :copen can target the just-opened list window itself.
---@param opts? { severity?: integer }
local function workspace_diagnostics(opts)
  vim.diagnostic.setqflist(vim.tbl_extend("force", { open = true }, opts or {}))
end

--- Populates and opens the current buffer's diagnostics in the location
--- list. See workspace_diagnostics for why `open` is passed.
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
