-- Vendored from nvim-lspconfig's lsp/marksman.lua (reference source, not a
-- runtime dependency; see AGENTS.md's Native-First Philosophy). Marksman
-- provides completion, cross-references, and diagnostics for Markdown.

---@type vim.lsp.Config
return {
  cmd = { "marksman", "server" },
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = { ".marksman.toml", ".git" },
}
