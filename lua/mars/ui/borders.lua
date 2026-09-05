-- Border style for floating windows and popups. style() reads
-- vim.g.mars_border_style at point-of-use so local.lua overrides apply.

local M = {}

--- Returns the configured border style.
---@return string
function M.style()
  return vim.g.mars_border_style or "rounded"
end

--- Applies the border style to winborder, pumborder, and the diagnostic float
--- config. Re-run from init.lua after local.lua.
function M.setup()
  local s = M.style()
  vim.o.winborder = s
  vim.o.pumborder = s
  vim.diagnostic.config({ float = { border = s } })
end

M.setup()

return M
