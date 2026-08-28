-- WP goes to intelephense; the root_dir gate refuses WP buffers so they never overlap.

---@type vim.lsp.Config
return {
  cmd = { "phpantom_lsp" },
  filetypes = { "php" },
  root_dir = function(bufnr, on_dir)
    if require("mars.helpers.php_project").wp_root(bufnr) then
      return
    end
    -- `nvim_buf_get_name`, not `bufname()`: the root must be absolute.
    local buf_dir = vim.fs.abspath(vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    on_dir(vim.fs.root(bufnr, { "composer.json", ".git" }) or buf_dir)
  end,
}
