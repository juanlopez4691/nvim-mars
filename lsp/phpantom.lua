-- WP goes to intelephense; the root_dir gate refuses WP buffers so they never overlap.

---@type vim.lsp.Config
return {
  cmd = { "phpantom_lsp" },
  filetypes = { "php" },
  root_dir = function(bufnr, on_dir)
    if require("mars.helpers.php_project").wp_root(bufnr) then
      return -- WordPress goes to intelephense
    end
    on_dir(vim.fs.root(bufnr, { "composer.json", ".git" }) or vim.fs.dirname(vim.fn.bufname(bufnr)))
  end,
}
