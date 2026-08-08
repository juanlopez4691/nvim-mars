-- Activates the native LSP configs defined under lsp/*.lua (see :help
-- lsp-config). Each server is configured declaratively in its own file;
-- this is the single place that turns them on.

vim.lsp.enable({
  "lua_ls",
})
