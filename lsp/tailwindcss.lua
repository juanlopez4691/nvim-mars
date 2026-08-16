-- Vendored from nvim-lspconfig's lsp/tailwindcss.lua (reference source, not
-- a runtime dependency; see AGENTS.md's Native-First Philosophy), trimmed
-- to the filetypes actually edited here and with root_dir reduced to plain
-- config-file/marker lookup (no package.json dependency sniffing). PHP,
-- Blade, and Twig views mix inline HTML with template directives, so they're
-- mapped to the "html" language in includeLanguages to get class-name
-- completion and hover inside them.

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local cmd = "tailwindcss-language-server"
    if (config or {}).root_dir then
      local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin", cmd)
      if vim.fn.executable(local_cmd) == 1 then
        cmd = local_cmd
      end
    end
    return vim.lsp.rpc.start({ cmd, "--stdio" }, dispatchers)
  end,
  filetypes = {
    "blade",
    "twig",
    "php",
    "html",
    "css",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  settings = {
    tailwindCSS = {
      classAttributes = {
        "class",
        "className",
        "class:list",
        "classList",
        "ngClass",
      },
      includeLanguages = {
        php = "html",
        blade = "html",
        twig = "html",
      },
    },
  },
  before_init = function(_, config)
    config.settings = vim.tbl_deep_extend("keep", config.settings, {
      editor = { tabSize = vim.lsp.util.get_effective_tabstop() },
    })
  end,
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
    local root_markers = {
      "tailwind.config.js",
      "tailwind.config.cjs",
      "tailwind.config.mjs",
      "tailwind.config.ts",
      "postcss.config.js",
      "postcss.config.cjs",
      "postcss.config.mjs",
      "postcss.config.ts",
      ".git",
    }
    local fname = vim.api.nvim_buf_get_name(bufnr)
    on_dir(vim.fs.dirname(vim.fs.find(root_markers, { path = fname, upward = true })[1]))
  end,
}
