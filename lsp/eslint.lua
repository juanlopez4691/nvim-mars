-- Vendored from nvim-lspconfig's lsp/eslint.lua (reference source, not a
-- runtime dependency; see AGENTS.md's Native-First Philosophy). Two changes
-- from upstream: the `require("lspconfig.util")` call is dropped (that
-- module belongs to the plugin, not to us), which means the root_dir probe
-- no longer treats a legacy `eslintConfig` field inside package.json as a
-- config file; modern ESLint (9+) doesn't read that field either, so this
-- only affects very old setups. And the `nvim-0.11.3` version check is gone
-- since this config targets Neovim 0.12+ only.

local eslint_config_files = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
}

---@type vim.lsp.Config
return {
  cmd = function(dispatchers, config)
    local cmd = "vscode-eslint-language-server"
    if (config or {}).root_dir then
      local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin", cmd)
      if vim.fn.executable(local_cmd) == 1 then
        cmd = local_cmd
      end
    end
    return vim.lsp.rpc.start({ cmd, "--stdio" }, dispatchers)
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
    "astro",
    "htmlangular",
  },
  workspace_required = true,
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, "LspEslintFixAll", function()
      client:request_sync("workspace/executeCommand", {
        command = "eslint.applyAllFixes",
        arguments = {
          {
            uri = vim.uri_from_bufnr(bufnr),
            version = vim.lsp.util.buf_versions[bufnr],
          },
        },
      }, nil, bufnr)
    end, {})
  end,
  root_dir = function(bufnr, on_dir)
    -- The project root is where the LSP can be started from. This server
    -- supports monorepos, so we look for a package manager lock file first
    -- and only fall back to the working directory.
    local root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }
    root_markers = { root_markers, { ".git" } }

    -- Deno projects use their own LSP, not ESLint.
    if vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" }) then
      return
    end

    local project_root = vim.fs.root(bufnr, root_markers) or vim.fn.getcwd()

    -- Only attach where a buffer is actually covered by an ESLint config
    -- file somewhere between it and the project root.
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local is_buffer_using_eslint = vim.fs.find(eslint_config_files, {
      path = filename,
      type = "file",
      limit = 1,
      upward = true,
      stop = vim.fs.dirname(project_root),
    })[1]
    if not is_buffer_using_eslint then
      return
    end

    on_dir(project_root)
  end,
  -- https://github.com/Microsoft/vscode-eslint#settings-options
  settings = {
    validate = "on",
    useESLintClass = false,
    experimental = {},
    codeActionOnSave = {
      enable = false,
      mode = "all",
    },
    format = true,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = {
      shortenToSingleLine = false,
    },
    nodePath = "",
    workingDirectory = { mode = "auto" },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = "separateLine",
      },
      showDocumentation = {
        enable = true,
      },
    },
  },
  before_init = function(_, config)
    -- The "workspaceFolder" is a VSCode concept: it limits how far the
    -- server will traverse the file system when locating the ESLint config.
    local root_dir = config.root_dir
    if root_dir then
      config.settings = config.settings or {}
      config.settings.workspaceFolder = {
        uri = vim.uri_from_fname(root_dir),
        name = vim.fn.fnamemodify(root_dir, ":t"),
      }

      -- Support Yarn2 (PnP) projects.
      local pnp_cjs = root_dir .. "/.pnp.cjs"
      local pnp_js = root_dir .. "/.pnp.js"
      if type(config.cmd) == "table" and (vim.uv.fs_stat(pnp_cjs) or vim.uv.fs_stat(pnp_js)) then
        config.cmd = vim.list_extend({ "yarn", "exec" }, config.cmd --[[@as table]])
      end
    end
  end,
  handlers = {
    ["eslint/openDoc"] = function(_, result)
      if result then
        vim.ui.open(result.url)
      end
      return {}
    end,
    ["eslint/confirmESLintExecution"] = function(_, result)
      if not result then
        return
      end
      return 4 -- approved
    end,
    ["eslint/probeFailed"] = function()
      vim.notify("[eslint] ESLint probe failed.", vim.log.levels.WARN)
      return {}
    end,
    ["eslint/noLibrary"] = function()
      vim.notify("[eslint] Unable to find ESLint library.", vim.log.levels.WARN)
      return {}
    end,
  },
}
