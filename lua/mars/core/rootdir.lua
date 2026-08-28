-- Project-root detection computed on demand: an attached LSP client's own
-- root_dir/workspace_folders (servers already detect their own root), then
-- the nearest ".git" ancestor, then 'cwd'. Never touches Neovim's actual
-- cwd; callers pass the root explicitly, so a wrong guess affects only
-- that one call and cwd never flip-flops on buffer switches.

local M = {}

--- An attached LSP client's root_dir/workspace_folder that actually
--- contains `name`, or nil if none qualifies.
---@param buf integer
---@param name string absolute path
---@return string?
local function lsp_root(buf, name)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    local dirs = {}
    for _, ws in ipairs(client.workspace_folders or {}) do
      dirs[#dirs + 1] = vim.uri_to_fname(ws.uri)
    end
    if client.root_dir then
      dirs[#dirs + 1] = client.root_dir
    end
    for _, dir in ipairs(dirs) do
      if vim.startswith(name, dir .. "/") then
        return dir
      end
    end
  end
  return nil
end

--- The project root for `buf`: LSP root, else nearest ".git" ancestor,
--- else 'cwd'.
---@param buf? integer
---@return string
function M.get(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= "" then
    local ok, git_root = pcall(vim.fs.root, buf, ".git")
    local root = lsp_root(buf, name) or (ok and git_root) or nil
    if root then
      return root
    end
  end
  return vim.fn.getcwd()
end

return M
