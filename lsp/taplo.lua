-- Vendored from nvim-lspconfig's lsp/taplo.lua (reference source, not a
-- runtime dependency; see AGENTS.md's Native-First Philosophy).

---@type vim.lsp.Config
return {
  cmd = { "taplo", "lsp", "stdio" },
  filetypes = { "toml" },
  root_markers = { ".taplo.toml", "taplo.toml", ".git" },
}
