-- Vendored from nvim-lspconfig's lsp/lua_ls.lua, plus the config-aware
-- on_init from that file's doc comment: the LuaJIT/vim-global augmentation
-- is scoped to editing Mars's own config, not any Lua project.

local root_markers1 = {
  ".emmyrc.json",
  ".luarc.json",
  ".luarc.jsonc",
}
local root_markers2 = {
  ".luacheckrc",
  ".stylua.toml",
  "stylua.toml",
  "selene.toml",
  "selene.yml",
}

---@type vim.lsp.Config
return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { root_markers1, root_markers2, { ".git" } },
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      local has_own_luarc = vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc")
      if path ~= vim.fn.stdpath("config") and has_own_luarc then
        return
      end
    end

    client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
      Lua = {
        runtime = {
          version = "LuaJIT",
          path = { "lua/?.lua", "lua/?/init.lua" },
        },
        workspace = {
          checkThirdParty = false,
          library = { vim.env.VIMRUNTIME },
        },
        diagnostics = {
          globals = { "vim" },
        },
      },
    })
  end,
  settings = {
    Lua = {
      codeLens = { enable = true },
      hint = { enable = true, semicolon = "Disable" },
    },
  },
}
