-- Vendored from nvim-lspconfig's lsp/marksman.lua (completion, xrefs, and
-- diagnostics for Markdown).

---@type vim.lsp.Config
return {
  cmd = { "marksman", "server" },
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = { ".marksman.toml", ".git" },
}
