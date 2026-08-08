-- PHP/Xdebug DAP launch configs (NEO-45), built on top of the debugging
-- stack wired up by lua/mars/plugins/dap.lua. Kept in its own file rather
-- than extending dap.lua directly: everything below is just table
-- assignments on the shared `dap` module, read lazily whenever a debug
-- session actually starts (not at require time), so it's safe to set
-- independently of dap.lua's own lazy `mars.pack.on()` setup.
--
-- Respects an explicit user override: if the project already defines its
-- own .vscode/launch.json, this module does nothing and lets that file win.
--
-- The actual wiring is deferred to VimEnter (via `mars.pack.on`, reused
-- here purely for its generic once-only event deferral; no `.add()` call:
-- nvim-dap is already registered by dap.lua). This isn't about lazy-
-- loading; it's required for correctness: `init.lua`'s `require_dir`
-- processes `lua/mars/plugins/*.lua` in sorted order, and
-- "dap-php.lua" < "dap.lua" byte-wise, so this file is `require()`-d
-- *before* dap.lua's own top-level `mars.pack.add()` call runs. Requiring
-- "dap" here at top level would fail with "module 'dap' not found". By
-- VimEnter, `require_dir` has fully finished regardless of that ordering,
-- so `require("dap")` is safe.

if vim.fn.filereadable(".vscode/launch.json") == 1 then
  return
end

--- Wires `dap.adapters.php` to the Mason-installed `php-debug-adapter`
--- binary (see lua/mars/plugins/mason.lua's `ensure_installed` list).
--- Resolved via mason-registry's own install path rather than
--- `vim.fn.exepath`, so it works regardless of whether Mason's shim
--- directory is on PATH yet. Mirrors mason-nvim-dap's own default adapter
--- mapping (`mason-nvim-dap/mappings/adapters/php.lua`): an `executable`
--- adapter pointing directly at the installed wrapper script, which
--- already knows how to invoke Node internally. A no-op (with no
--- notification) if the package isn't known or installed yet; the next
--- successful Mason install leaves this correct on the next Neovim start.
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

    --- `dap.configurations.php`: two Xdebug "Listen for Xdebug" launch
    --- configs. The Docker/Sail variant maps the container's project path
    --- (`/var/www/html`, the standard Laravel Sail path) to the local
    --- workspace; the local variant omits path mapping for PHP running
    --- directly on the host.
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
