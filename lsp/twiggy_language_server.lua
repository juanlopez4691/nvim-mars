-- Vendored from nvim-lspconfig's lsp/twiggy_language_server.lua (reference
-- source, not a runtime dependency; see AGENTS.md's Native-First
-- Philosophy).

---@type vim.lsp.Config
return {
  cmd = { "twiggy-language-server", "--stdio" },
  filetypes = { "twig" },
  root_markers = { "composer.json", ".git" },
}
