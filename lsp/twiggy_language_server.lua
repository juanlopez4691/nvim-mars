-- Vendored from nvim-lspconfig's lsp/twiggy_language_server.lua.

---@type vim.lsp.Config
return {
  cmd = { "twiggy-language-server", "--stdio" },
  filetypes = { "twig" },
  root_markers = { "composer.json", ".git" },
}
