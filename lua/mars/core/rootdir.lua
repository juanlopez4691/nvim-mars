-- Native project-root detection, computed on demand.
-- Prefers an
-- attached LSP client's own root_dir/workspace_folders (servers already do
-- sophisticated detection of their own; vtsls looks for a lockfile,
-- intelephense for composer.json; so this reuses that instead of guessing
-- again), then the nearest ".git" ancestor, then 'cwd' as a last resort.
-- Crucially, unlike an autocmd-driven `:cd`, this never touches Neovim's
-- actual working directory: a caller that wants the detected root to
-- affect where a command runs (`:grep`, a picker, ...) passes it explicitly
-- itself, so a wrong guess only affects that one call, not the whole
-- session, and cwd never flip-flops just from switching buffers.

local M = {}

---@type table<integer, string>
local cache = {}

--- The root_dir/workspace_folder of an LSP client attached to `buf` whose
--- root actually contains `name` (the buffer's own absolute path), or nil
--- if no attached client's root qualifies.
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

--- The project root for `buf`: an attached LSP client's own root when
--- available, else the nearest ".git" ancestor, else 'cwd'. Cached per
--- buffer until something that could change the answer happens.
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
