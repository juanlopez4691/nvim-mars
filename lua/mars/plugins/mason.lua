-- mason.nvim: cross-platform installer for the external LSP servers,
-- formatters, linters, and debug adapters this config expects (see
-- AGENTS.md's approved exception list). Only mason.nvim itself is used;
-- no mason-lspconfig or mason-tool-installer; servers are wired up natively
-- via `vim.lsp.enable`, and the ensure-install below is a small first-party
-- stand-in for what mason-tool-installer would otherwise provide.

require("mars.pack").add({
  { src = "https://github.com/mason-org/mason.nvim" },
})

--- Tools this config expects to stay installed, keyed by their name in
--- Mason's own registry (`:Mason` to browse it).
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

--- Install every entry of `ensure_installed` that isn't on disk yet.
--- Refreshes the registry first (a no-op when its local cache is already
--- fresh), then installs the missing packages in parallel. Fully
--- asynchronous and non-interactive: nothing here blocks startup or waits
--- on user input, and a single summary notification is sent once every
--- install has settled rather than one per package.
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

-- `mason.setup()` only needs to run once; guarded here rather than through
-- `mars.pack`'s `cmd` trigger, since that trigger expects the plugin itself
-- to own the command being lazy-loaded, and `:MarsMasonInstall` is first
-- party.
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
