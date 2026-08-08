-- Vendored from nvim-lspconfig's lsp/laravel_ls.lua (reference source, not a
-- runtime dependency; see AGENTS.md's Native-First Philosophy).

---@type vim.lsp.Config
return {
  cmd = { "laravel-ls" },
  filetypes = { "php", "blade" },
  root_markers = { "artisan" },
}
