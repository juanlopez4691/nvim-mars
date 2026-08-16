-- Vendored from nvim-lspconfig's lsp/docker_compose_language_service.lua.
-- If it won't attach on a compose file, confirm the buffer's filetype is
-- `yaml.docker-compose` (`:set filetype=yaml.docker-compose`).

---@type vim.lsp.Config
return {
  cmd = { "docker-compose-langserver", "--stdio" },
  filetypes = { "yaml.docker-compose" },
  root_markers = { "docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml" },
}
