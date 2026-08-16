-- Shared text helpers for modules that render fixed-width windows: display-
-- width truncation and '%'-escaping for statusline/winbar strings.

local M = {}

--- Truncates `s` to at most `width` display columns, walking characters
--- (not bytes) so multi-byte glyphs aren't split. With `opts.ellipsis`,
--- appends "…" when the text doesn't fit.
---@param s string
---@param width integer
---@param opts? { ellipsis?: boolean }
---@return string
function M.truncate_to_width(s, width, opts)
  if width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(s) <= width then
    return s
  end
  local budget = width
  local suffix = ""
  if opts and opts.ellipsis then
    suffix = "…"
    budget = width - vim.fn.strdisplaywidth(suffix)
    if budget <= 0 then
      return suffix
    end
  end

  local last_fit = ""
  for i = 1, vim.fn.strchars(s) do
    local candidate = vim.fn.strcharpart(s, 0, i)
    if vim.fn.strdisplaywidth(candidate) > budget then
      break
    end
    last_fit = candidate
  end
  return last_fit .. suffix
end

--- Doubles every "%" so `<Esc>`/buffer text survives the nested parse
--- Neovim performs on an expression-based 'statusline'/'winbar'.
---@param s string
---@return string
function M.escape(s)
  return (s:gsub("%%", "%%%%"))
end

return M
