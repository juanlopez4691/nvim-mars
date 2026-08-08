-- Entry point. See AGENTS.md's Code Structure section for the directory
-- layout this bootstraps.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

--- Requires every `.lua` file under `lua/mars/<dir>/` (searched across
--- 'runtimepath', so it works whether Mars is the active config or vendored
--- elsewhere). Does nothing if the directory doesn't exist yet; new
--- directories don't need a matching require_dir call added by hand.
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
-- so it can override anything set above without ever touching a tracked
-- file; nothing to commit, nothing to conflict with on pull.
pcall(require, "mars.local")
