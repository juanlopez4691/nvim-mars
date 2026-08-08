-- nvim-treesitter (main branch): parser install/update only. Runtime
-- highlighting/folding is native (vim.treesitter.*); see below. The plugin
-- does not support lazy-loading (per its own README), so this loads eagerly.

require("mars.pack").add({
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

local parsers = {
  "lua",
  "vim",
  "vimdoc",
  "query",
  "bash",
  "css",
  "html",
  "javascript",
  "json",
  "markdown",
  "markdown_inline",
  "php",
  "phpdoc",
  "typescript",
  "tsx",
  "yaml",
  "toml",
  "blade",
  "vue",
}

require("nvim-treesitter").install(parsers)

-- Highlighting isn't automatic per-filetype (see nvim-treesitter's README).
local filetypes = {
  "lua",
  "vim",
  "help",
  "query",
  "bash",
  "css",
  "html",
  "javascript",
  "javascriptreact",
  "json",
  "jsonc",
  "markdown",
  "php",
  "typescript",
  "typescriptreact",
  "yaml",
  "toml",
  "vue",
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = filetypes,
  callback = function()
    vim.treesitter.start()
  end,
})

-- Folding: default to treesitter, upgrade to LSP folding per-window when the
-- attaching client supports it.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/foldingRange") then
      local win = vim.api.nvim_get_current_win()
      vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
    end
  end,
})
