-- Vendored from nvim-lspconfig's lsp/laravel_ls.lua.

---@type vim.lsp.Config
return {
  cmd = { "laravel-ls" },
  filetypes = { "php", "blade" },
  root_markers = { "artisan" },
}
