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
    ["_typescript.moveToFileRefactoring"] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      ---@type string, string, vim.lsp.Range
      local action, uri, range = unpack(command.arguments)

      local function move(newf)
        client:request("workspace/executeCommand", {
          command = command.command,
          arguments = { action, uri, range, newf },
        })
      end

      local fname = vim.uri_to_fname(uri)
      client:request("workspace/executeCommand", {
        command = "typescript.tsserverRequest",
        arguments = {
          "getMoveToRefactoringFileSuggestions",
          {
            file = fname,
            startLine = range.start.line + 1,
            startOffset = range.start.character + 1,
            endLine = range["end"].line + 1,
            endOffset = range["end"].character + 1,
          },
        },
      }, function(err, result)
        if err then
          vim.notify(("vtsls move-to-file suggestions failed: %s"):format(err.message), vim.log.levels.WARN)
          return
        end
        local files = result and result.body and result.body.files
        if not files then
          return
        end
        table.insert(files, 1, "Enter new path...")
        vim.ui.select(files, {
          prompt = "Select move destination:",
          format_item = function(f)
            return vim.fn.fnamemodify(f, ":~:.")
          end,
        }, function(f)
          if f and f:find("^Enter new path") then
            vim.ui.input({
              prompt = "Enter move destination:",
              default = vim.fn.fnamemodify(fname, ":h") .. "/",
              completion = "file",
            }, function(newf)
              if newf then
                move(newf)
              end
            end)
          elseif f then
            move(f)
          end
        end)
      end)
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
