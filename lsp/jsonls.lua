-- Vendored from nvim-lspconfig's lsp/jsonls.lua. No SchemaStore.nvim (the
-- ~800-entry catalog plugin): a file that declares "$schema" already makes
-- the server fetch its own schema, and settings.json.schemas below hand-picks
-- the few name-matched catalog entries likely to matter here (package.json,
-- tsconfig.json, composer.json, ...), copied verbatim from schemastore.org.

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local cmd = "vscode-json-language-server"
    if (config or {}).root_dir then
      local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin", cmd)
      if vim.fn.executable(local_cmd) == 1 then
        cmd = local_cmd
      end
    end
    return vim.lsp.rpc.start({ cmd, "--stdio" }, dispatchers)
  end,
  filetypes = { "json", "jsonc" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
  settings = {
    json = {
      schemas = {
        { fileMatch = { "package.json" }, url = "https://www.schemastore.org/package.json" },
        { fileMatch = { "tsconfig*.json" }, url = "https://www.schemastore.org/tsconfig.json" },
        { fileMatch = { "jsconfig.json" }, url = "https://www.schemastore.org/jsconfig.json" },
        { fileMatch = { ".eslintrc", ".eslintrc.json" }, url = "https://www.schemastore.org/eslintrc.json" },
        { fileMatch = { ".prettierrc", ".prettierrc.json" }, url = "https://www.schemastore.org/prettierrc.json" },
        { fileMatch = { "composer.json" }, url = "https://getcomposer.org/schema.json" },
      },
    },
  },
}
