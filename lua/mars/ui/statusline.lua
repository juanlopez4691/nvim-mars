-- Native statusline wired up as an expression option. render() runs on
-- nearly every redraw, so anything touching the filesystem is resolved
-- cheaply per call and nothing expensive is computed inline.

local color = require("mars.color")
local text = require("mars.text")

local M = {}

--- Wraps text in a built-in highlight group, resetting back to the
--- statusline's own default group afterwards. With no group, just escapes.
---@param text_str string
---@param group? string
---@return string
local function hl(text_str, group)
  if not group then
    return text.escape(text_str)
  end
  return "%#" .. group .. "#" .. text.escape(text_str) .. "%*"
end

--- Joins non-empty segments with a single space.
---@param parts string[]
---@return string
local function join(parts)
  local out = {}
  for _, part in ipairs(parts) do
    if part ~= "" then
      out[#out + 1] = part
    end
  end
  return table.concat(out, " ")
end

--- Mode source group -> derived block group that paints the mode color as a
--- background instead of a text color. Re-derived per colorscheme.
---@type table<string, string>
local MODE_HL = {
  DiagnosticOk = "MarsStatuslineModeOk",
  DiagnosticInfo = "MarsStatuslineModeInfo",
  DiagnosticWarn = "MarsStatuslineModeWarn",
  DiagnosticError = "MarsStatuslineModeError",
  Title = "MarsStatuslineModeTitle",
  Comment = "MarsStatuslineModeComment",
  StatusLine = "MarsStatuslineModeStatus",
}

--- (Re)derives the mode-block highlights from the active colorscheme: each
--- mode's color becomes the block's background, with a contrasting
--- black/white label on top.
local function apply_mode_highlights()
  for source, name in pairs(MODE_HL) do
    local fg = vim.api.nvim_get_hl(0, { name = source }).fg
    if fg then
      vim.api.nvim_set_hl(0, name, {
        fg = color.readable_fg(string.format("%06x", fg)),
        bg = "#" .. string.format("%06x", fg),
      })
    end
  end
end

---@return string label
---@return string group
local function mode_info()
  local c = vim.fn.mode():sub(1, 1)
  if c == "n" then
    return "NORMAL", MODE_HL.DiagnosticOk
  elseif c == "i" then
    return "INSERT", MODE_HL.DiagnosticInfo
  elseif c == "v" then
    return "VISUAL", MODE_HL.DiagnosticWarn
  elseif c == "V" then
    return "V-LINE", MODE_HL.DiagnosticWarn
  elseif c == "\22" then
    return "V-BLOCK", MODE_HL.DiagnosticWarn
  elseif c == "s" or c == "S" or c == "\19" then
    return "SELECT", MODE_HL.DiagnosticWarn
  elseif c == "R" then
    return "REPLACE", MODE_HL.DiagnosticError
  elseif c == "c" then
    return "COMMAND", MODE_HL.Title
  elseif c == "r" then
    return "PROMPT", MODE_HL.Title
  elseif c == "t" then
    return "TERMINAL", MODE_HL.Comment
  end
  return c:upper(), MODE_HL.StatusLine
end

local group = vim.api.nvim_create_augroup("mars_statusline", { clear = true })

apply_mode_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  desc = "Re-derive mode-block highlights after the colorscheme (re)loads",
  callback = apply_mode_highlights,
})

---@param bufnr integer
---@return string
local function pretty_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end

  local path = vim.fn.fnamemodify(name, ":p")
  local root = vim.fs.root(bufnr, { ".git" })
  local rel
  if root and path:sub(1, #root) == root then
    rel = path:sub(#root + 2)
  else
    rel = vim.fn.fnamemodify(path, ":~")
  end

  if vim.bo[bufnr].modified then
    rel = rel .. (vim.g.have_nerd_font and " ●" or " [+]")
  end
  if vim.bo[bufnr].readonly then
    rel = rel .. (vim.g.have_nerd_font and " 󰌾" or " [RO]")
  end
  return rel
end

---@param bufnr integer
---@return string
local function lsp_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    return ""
  end

  local names = {}
  for _, client in ipairs(clients) do
    names[#names + 1] = client.name
  end
  table.sort(names)
  return hl(table.concat(names, ", "), "Special")
end

---@return string
local function macro_recording()
  local reg = vim.fn.reg_recording()
  if reg == "" then
    return ""
  end
  local label = (vim.g.have_nerd_font and "󰻂 REC @" or "REC @") .. reg
  return hl(label, "DiagnosticWarn")
end

vim.api.nvim_create_autocmd("RecordingEnter", {
  group = group,
  desc = "Repaint the statusline when macro recording starts",
  callback = function()
    vim.cmd.redrawstatus()
  end,
})

vim.api.nvim_create_autocmd("RecordingLeave", {
  group = group,
  desc = "Repaint the statusline once macro recording has fully stopped",
  callback = function()
    vim.defer_fn(function()
      vim.cmd.redrawstatus()
    end, 50)
  end,
})

---@return string
local function ruler()
  local line, total = vim.fn.line("."), vim.fn.line("$")
  local col = vim.fn.virtcol(".")
  local percent = total > 0 and math.floor((line / total) * 100) or 0
  return hl(("%d:%-2d %3d%%"):format(line, col, percent))
end

--- Renders the statusline for the window being redrawn. Runs once per
--- window, including inactive ones, so buffer-derived segments must resolve
--- their buffer through `g:statusline_winid`, not the current window.
--- `mode_info()` and `ruler()` are inherently about the current window and
--- are exempt.
---@return string
function M.render()
  local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local mode_label, mode_group = mode_info()
  local ft = vim.bo[bufnr].filetype

  local left = join({
    hl(" " .. mode_label .. " ", mode_group),
    hl(ft ~= "" and ft or "no ft", "Comment"),
    hl(pretty_path(bufnr), "Directory"),
  })

  local right = join({
    lsp_clients(bufnr),
    macro_recording(),
    ruler(),
  })

  return left .. "%=" .. right
end

vim.o.statusline = "%!v:lua.require'mars.ui.statusline'.render()"

return M
