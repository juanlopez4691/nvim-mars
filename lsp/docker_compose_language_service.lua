-- Vendored from nvim-lspconfig's lsp/docker_compose_language_service.lua
-- (reference source, not a runtime dependency; see AGENTS.md's Native-First
-- Philosophy). If it doesn't attach on a compose file, confirm the buffer's
-- filetype is actually `yaml.docker-compose` (`:set filetype=yaml.docker-compose`).

---@type vim.lsp.Config
return {
  cmd = { "docker-compose-langserver", "--stdio" },
  filetypes = { "yaml.docker-compose" },
  root_markers = { "docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml" },
}
