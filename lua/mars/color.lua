-- Colour helpers shared by the hex swatches (patterns.lua) and the statusline
-- mode blocks: relative luminance and a readable black/white text colour.

local M = {}

--- Relative luminance of an sRGB channel value (0-1), per the WCAG formula.
---@param channel number
---@return number
local function linearize(channel)
  if channel <= 0.03928 then
    return channel / 12.92
  end
  return ((channel + 0.055) / 1.055) ^ 2.4
end

--- Readable foreground (black/white) for a hex background: whichever of the
--- two has the higher WCAG contrast ratio (a plain luminance threshold
--- misjudges medium colours like orange).
---@param hex string 6 hex digits, lowercase, no leading '#'
---@return string
function M.readable_fg(hex)
  local r = linearize(tonumber(hex:sub(1, 2), 16) / 255)
  local g = linearize(tonumber(hex:sub(3, 4), 16) / 255)
  local b = linearize(tonumber(hex:sub(5, 6), 16) / 255)
  local l = 0.2126 * r + 0.7152 * g + 0.0722 * b
  -- Contrast against pure black (l=0) and pure white (l=1).
  local vs_black = (l + 0.05) / 0.05
  local vs_white = 1.05 / (l + 0.05)
  return vs_black >= vs_white and "#000000" or "#ffffff"
end

return M
