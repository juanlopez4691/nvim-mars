-- PHP/Xdebug DAP launch configs (NEO-45), on top of lua/mars/plugins/dap.lua.
-- Everything here is table assignments on the shared `dap` module, read lazily
-- when a session starts, so it's safe to set independently of dap.lua's lazy
-- setup. Respects an existing .vscode/launch.json; if the project defines
-- one, this module does nothing and lets that file win.
--
-- Deferred to VimEnter via `mars.pack.on` (no `.add()`; dap.lua already
-- registers nvim-dap). This is required for correctness, not lazy-loading:
-- `require_dir` processes plugins/*.lua in sorted order and "dap-php.lua" <
-- "dap.lua" byte-wise, so a top-level require("dap") here would fail with
-- "module 'dap' not found"; by VimEnter require_dir has fully finished.

if vim.fn.filereadable(".vscode/launch.json") == 1 then
  return
end

--- Wires `dap.adapters.php` to the Mason-installed `php-debug-adapter`
--- binary, resolved via mason-registry so it works regardless of whether
--- Mason's shim dir is on PATH. Mirrors mason-nvim-dap's own default php
--- mapping (an `executable` adapter at the wrapper script). No-op until the
--- package is installed; a later successful Mason install fixes it next start.
---@param dap table The `dap` module.
---@return nil
local function setup_adapter(dap)
  local ok_registry, mason_registry = pcall(require, "mason-registry")
  if not ok_registry then
    return
  end

  local ok_pkg, pkg = pcall(mason_registry.get_package, "php-debug-adapter")
  if not ok_pkg or not pkg:is_installed() then
    return
  end

  dap.adapters.php = {
    type = "executable",
    command = pkg:get_install_path() .. "/php-debug-adapter",
  }
end

require("mars.pack").on({
  event = "VimEnter",
  config = function()
    local dap = require("dap")

    setup_adapter(dap)

    --- Two Xdebug "Listen for Xdebug" launch configs: a Docker/Sail variant
    --- mapping the container path `/var/www/html` to the workspace, and a
    --- host-native variant with no path mapping.
    dap.configurations.php = {
      {
        type = "php",
        request = "launch",
        name = "Listen for Xdebug (Docker/Sail)",
        port = 9003,
        pathMappings = {
          ["/var/www/html"] = "${workspaceFolder}",
        },
      },
      {
        type = "php",
        request = "launch",
        name = "Listen for Xdebug (local)",
        port = 9003,
        -- No pathMappings: source paths match the workspace directly.
      },
    }
  end,
})
