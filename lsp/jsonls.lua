-- Vendored from nvim-lspconfig's lsp/jsonls.lua (reference source, not a
-- runtime dependency; see AGENTS.md's Native-First Philosophy).
--
-- Schema wiring: `vscode-json-language-server` ships its own HTTP client
-- (request-light) and already fetches a schema on its own whenever a file
-- declares one via `"$schema"`; no config needed for that case. What it
-- does NOT do on its own is the SchemaStore.org catalog's other trick:
-- associating a schema with a file purely by *name*, for files that never
-- set `$schema` (package.json, tsconfig.json, composer.json, ...). VSCode
-- gets that from its `json.schemas` setting, normally populated by
-- SchemaStore.nvim vendoring the whole ~800-entry catalog.
--
-- That plugin is off the table here, and fetching+parsing the live catalog
-- from this config file would mean a blocking network call at startup for a
-- file that's supposed to be declarative. Instead, `settings.json.schemas`
-- below hand-picks the handful of catalog entries most likely to matter in
-- this config's projects (JS/TS tooling, Composer), copied verbatim
-- (fileMatch + url) from https://www.schemastore.org/api/json/catalog.json.
-- Anything not listed still validates fine as long as it sets its own
-- `$schema`.

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
