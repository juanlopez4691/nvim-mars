vim.g.mapleader = " "
vim.g.maplocalleader = " "

--- Requires every `.lua` file under `lua/mars/<dir>/`; does nothing if the
--- directory is absent.
---@param dir string Directory name under lua/mars/, e.g. "core"
local function require_dir(dir)
  local files = vim.api.nvim_get_runtime_file(("lua/mars/%s/*.lua"):format(dir), true)
  table.sort(files)
  for _, file in ipairs(files) do
    local module = file:match("lua/(.*)%.lua$"):gsub("/", ".")
    require(module)
  end
end

require_dir("core")
require_dir("plugins")
require_dir("ui")
require_dir("lang")

-- Local, gitignored overrides (see lua/mars/local.lua.example). Loaded last
-- so they can override anything set above.
pcall(require, "mars.local")
