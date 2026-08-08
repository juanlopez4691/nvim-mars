-- Vendored from nvim-lspconfig's lsp/dockerls.lua (reference source, not a
-- runtime dependency; see AGENTS.md's Native-First Philosophy).

---@type vim.lsp.Config
return {
  cmd = { "docker-langserver", "--stdio" },
  filetypes = { "dockerfile" },
  root_markers = { "Dockerfile" },
}
