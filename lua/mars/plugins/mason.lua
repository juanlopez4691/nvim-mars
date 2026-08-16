-- mason.nvim: cross-platform installer for the external LSP servers,
-- formatters, linters, and debug adapters this config expects. No
-- mason-lspconfig or mason-tool-installer: servers are wired up natively via
-- `vim.lsp.enable`, and `ensure_tools()` below is the first-party stand-in
-- for the tool installer.

require("mars.pack").add({
  { src = "https://github.com/mason-org/mason.nvim" },
})

-- `mason.setup()` prepends its bin/ dir to PATH only at VimEnter, too late
-- for an LSP server that spawns for a buffer opened at startup, so prepend
-- it here. Matching mason's own default install root; a missing dir on PATH
-- is harmless.
local sep = vim.fn.has("win32") == 1 and ";" or ":"
local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "mason", "bin")
if not vim.env.PATH:find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. sep .. vim.env.PATH
end

--- Tools this config expects to stay installed, keyed by Mason registry name.
local ensure_installed = {
  "blade-formatter",
  "docker-compose-language-service",
  "dockerfile-language-server",
  "intelephense",
  "json-lsp",
  "lua-language-server",
  "marksman",
  "php-cs-fixer",
  "php-debug-adapter",
  "phpcbf",
  "phpcs",
  "phpstan",
  "pint",
  "prettierd",
  "tailwindcss-language-server",
  "taplo",
  "vtsls",
}

--- Install every `ensure_installed` entry not on disk yet, after refreshing
--- the registry (a no-op when its cache is fresh). Asynchronous and
--- non-interactive: nothing blocks startup, and one summary notification is
--- sent once every install has settled.
local function ensure_tools()
  local registry = require("mason-registry")

  registry.refresh(function()
    local missing = {}
    for _, name in ipairs(ensure_installed) do
      if not registry.has_package(name) then
        vim.schedule(function()
          vim.notify(("mason: %q is not a known package"):format(name), vim.log.levels.WARN)
        end)
      elseif not registry.get_package(name):is_installed() then
        table.insert(missing, name)
      end
    end

    if #missing == 0 then
      return
    end

    local pending = #missing
    local failed = {}

    for _, name in ipairs(missing) do
      registry.get_package(name):install(nil, function(success)
        if not success then
          table.insert(failed, name)
        end

        pending = pending - 1
        if pending == 0 then
          vim.schedule(function()
            if #failed == 0 then
              vim.notify(("mason: installed %d tool(s)"):format(#missing), vim.log.levels.INFO)
            else
              vim.notify(("mason: failed to install %s"):format(table.concat(failed, ", ")), vim.log.levels.WARN)
            end
          end)
        end
      end)
    end
  end)
end

-- `mason.setup()` must run once; guarded here rather than via `mars.pack`'s
-- `cmd` trigger, which expects the plugin itself to own the lazy-loaded
-- command, and `:MarsMasonInstall` is first-party.
local mason_ready = false

--- @return nil
local function ensure_mason()
  if mason_ready then
    return
  end
  mason_ready = true
  require("mason").setup({})
end

require("mars.pack").on({
  event = "VimEnter",
  config = function()
    ensure_mason()
    ensure_tools()
  end,
})

vim.api.nvim_create_user_command("MarsMasonInstall", function()
  ensure_mason()
  ensure_tools()
end, { desc = "Install any missing Mason-managed tools" })
