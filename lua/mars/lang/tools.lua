-- Shared executable resolution for the format/lint modules, so the lookup
-- order lives in exactly one place.

local M = {}

--- Directories checked (relative to the project root, in order) before
--- falling back to a Mason-managed install and then bare PATH lookup.
---@type string[]
local PROJECT_DIRS = { "node_modules/.bin", "vendor/bin" }

--- Resolves an executable name to the path Mars should invoke, preferring a
--- project-local install over a Mason-managed one over PATH. The bare `name`
--- is returned when nothing resolves, so PATH handles it (or fails with a
--- clear "command not found").
---@param buf integer Buffer used to locate the project root
---@param name string Executable name, e.g. "prettierd"
---@param opts? { root?: string } `root` overrides project-root detection.
---@return string path Resolved absolute path, or `name` unchanged
function M.resolve(buf, name, opts)
  opts = opts or {}
  local root = opts.root or vim.fs.root(buf, { ".git" }) or vim.fn.getcwd()

  for _, dir in ipairs(PROJECT_DIRS) do
    local candidate = vim.fs.joinpath(root, dir, name)
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end

  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "mason", "bin", name)
  if vim.fn.executable(mason_bin) == 1 then
    return mason_bin
  end

  return name
end

return M
