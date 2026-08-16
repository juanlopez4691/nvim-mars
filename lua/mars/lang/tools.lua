-- Shared executable resolution for the format/lint modules. Kept as its own
-- module so the lookup order lives in exactly one place instead of being
-- reimplemented per formatter/linter.

local M = {}

--- Directories checked (relative to the project root, in order) before
--- falling back to a Mason-managed install and then bare PATH lookup.
---@type string[]
local PROJECT_DIRS = { "node_modules/.bin", "vendor/bin" }

--- Resolves an executable name to the path Mars should invoke, preferring a
--- project-local install over a Mason-managed one over PATH.
---
--- A project-local or Mason candidate is only returned when it actually
--- exists and is executable; otherwise the bare `name` is returned so the
--- caller can hand it to a shell/`vim.system` and let PATH resolve it (or
--- fail with a clear "command not found").
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
