-- PHP project detection shared by the two PHP language servers (intelephense
-- for WordPress, phpantom otherwise). WP is recognised by the classic install
-- markers, walking up from the buffer so theme/plugin repos nested under a
-- `wp-content` ancestor are caught too.

local M = {}

--- Nearest WordPress install root for a buffer, or nil if not inside one.
---@param bufnr integer
---@return string?
function M.wp_root(bufnr)
  -- Absolute, as vim.fs.root does it: `bufname()` is cwd-relative, and an
  -- upward walk from a relative path stops at the cwd.
  local dir = vim.fs.abspath(vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  local hits = vim.fs.find({ "wp-config.php", "wp-content", "wp-includes" }, {
    upward = true,
    path = dir,
  })
  return hits[1] and vim.fs.dirname(hits[1])
end

return M
