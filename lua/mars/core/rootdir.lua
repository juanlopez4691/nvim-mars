-- Project-root detection computed on demand: an attached LSP client's own
-- root_dir/workspace_folders (servers already detect their own root), then
-- the nearest ".git" ancestor, then 'cwd'. Never touches Neovim's actual
-- cwd; callers pass the root explicitly, so a wrong guess affects only
-- that one call and cwd never flip-flops on buffer switches.

local M = {}

---@type table<integer, string>
local cache = {}

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
      if name:sub(1, #dir + 1) == dir .. "/" then
        return dir
      end
    end
  end
  return nil
end

--- The project root for `buf`: LSP root, else nearest ".git" ancestor,
--- else 'cwd'. Cached per buffer until something that could change the
--- answer happens.
---@param buf? integer
---@return string
function M.get(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if cache[buf] then
    return cache[buf]
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local root
  if name ~= "" then
    local ok, git_root = pcall(vim.fs.root, buf, ".git")
    root = lsp_root(buf, name) or (ok and git_root) or nil
  end
  root = root or vim.fn.getcwd()

  cache[buf] = root
  return root
end

local augroup = vim.api.nvim_create_augroup("mars_root", { clear = true })

vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost", "DirChanged" }, {
  group = augroup,
  callback = function(ev)
    cache[ev.buf] = nil
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = augroup,
  callback = function(ev)
    cache[ev.buf] = nil
  end,
})

return M
