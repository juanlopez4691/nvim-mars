-- Vendored from nvim-lspconfig's lsp/vtsls.lua: keeps its lockfile-first
-- root_dir logic (steering clear of Deno projects) plus a lean set of
-- inlay-hint/completion settings.

local root_markers = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }

local typescript_settings = {
  updateImportsOnFileMove = { enabled = "always" },
  suggest = {
    completeFunctionCalls = true,
  },
  inlayHints = {
    enumMemberValues = { enabled = true },
    functionLikeReturnTypes = { enabled = true },
    parameterNames = { enabled = "literals" },
    parameterTypes = { enabled = true },
    propertyDeclarationTypes = { enabled = true },
    variableTypes = { enabled = false },
  },
}

---@type vim.lsp.Config
return {
  cmd = { "vtsls", "--stdio" },
  commands = {
    ["_typescript.moveToFileRefactoring"] = function(result, ctx)
      ---@type vim.lsp.ApplyWorkspaceEditParams
      local params = {
        edit = result.edit,
        label = result.label,
      }
      vim.lsp.util.apply_workspace_edit(params, ctx.client_id)
    end,
  },
  init_options = {
    hostInfo = "neovim",
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_dir = function(bufnr, on_dir)
    -- vtsls handles monorepos itself once started from the right root, so we
    -- only locate the nearest package-manager lockfile (falling back to
    -- .git), excluding Deno projects, which use a competing server.
    local deno_root = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" })
    local deno_lock_root = vim.fs.root(bufnr, { "deno.lock" })
    local project_root = vim.fs.root(bufnr, { root_markers, { ".git" } })

    if deno_lock_root and (not project_root or #deno_lock_root > #project_root) then
      -- deno.lock is closer than the package manager lock: abort.
      return
    end
    if deno_root and (not project_root or #deno_root >= #project_root) then
      -- deno.json(c) is closer than or equal to the package manager lock: abort.
      return
    end

    on_dir(project_root or vim.fn.getcwd())
  end,
  settings = {
    vtsls = {
      enableMoveToFileCodeAction = true,
      autoUseWorkspaceTsdk = true,
      experimental = {
        maxInlayHintLength = 30,
        completion = {
          enableServerSideFuzzyMatch = true,
        },
      },
    },
    typescript = typescript_settings,
    javascript = vim.tbl_deep_extend("force", {}, typescript_settings),
  },
}
