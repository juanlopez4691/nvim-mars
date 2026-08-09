-- Centralized border style for floating windows and popups. Call style()
-- at point-of-use (not at require-time) so that vim.g.mars_border_style
-- overrides from lua/mars/local.lua take effect.
--
-- To customize, set in lua/mars/local.lua:
--   vim.g.mars_border_style = "single"   -- "rounded" | "single" | "solid" | "none"
--   require("mars.ui.borders").setup()

local M = {}

--- Returns the currently configured border style.
--- Reads vim.g.mars_border_style at call time so local.lua overrides apply.
---@return string
function M.style()
  return vim.g.mars_border_style or "rounded"
end

--- Applies the current border style to winborder, pumborder, and the
--- diagnostic float config.
function M.setup()
  local s = M.style()
  vim.o.winborder = s
  vim.o.pumborder = s
  vim.diagnostic.config({ float = { border = s } })
end

-- Apply the default border style at startup.
M.setup()

return M
