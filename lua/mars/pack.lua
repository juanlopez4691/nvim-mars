-- Thin lazy-load wrapper around the native `vim.pack` (Neovim >= 0.12), which
-- has no built-in event/filetype/command-based lazy-loading of its own.
--
-- `vim.pack.add()` itself is cheap to call eagerly for every plugin: with the
-- default `load = false` (Neovim's default while init.lua is being sourced)
-- it installs the plugin on disk and makes it `require()`-able, without
-- running its `plugin/`/`ftdetect/` scripts. What actually costs boot time is
-- calling a plugin's own `setup()`; that's what `M.on()` below defers.

local M = {}

--- Install (if needed) and register plugins without loading their
--- `plugin/`/`ftdetect/` scripts. Skips the install confirmation prompt:
--- the plugin list is already reviewed by editing this config, so asking
--- again on first run is just friction (unlike `vim.pack.update()`, where
--- reviewing a diff of *changes* is genuinely useful and left at its
--- default).
---@param specs (string|vim.pack.Spec)[]
function M.add(specs)
  vim.pack.add(specs, { load = false, confirm = false })
end

--- Defer `opts.config()` until one of the given triggers fires. Runs at most
--- once. `opts.config` typically calls `require("plugin").setup(...)`.
---@param opts { event?: string|string[], ft?: string|string[], cmd?: string|string[], config: fun() }
function M.on(opts)
  local done = false
  local function run()
    if done then
      return
    end
    done = true
    opts.config()
  end

  if opts.event then
    vim.api.nvim_create_autocmd(opts.event, { once = true, callback = run })
  end

  if opts.ft then
    vim.api.nvim_create_autocmd("FileType", { pattern = opts.ft, once = true, callback = run })
  end

  local cmds = opts.cmd
  if type(cmds) == "string" then
    cmds = { cmds }
  end

  for _, name in ipairs(cmds or {}) do
    vim.api.nvim_create_user_command(name, function(cmd_opts)
      run()
      vim.cmd(("%s %s"):format(name, cmd_opts.args))
    end, { nargs = "*", bang = true })
  end
end

return M
