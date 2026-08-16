-- Thin lazy-load wrapper around native `vim.pack` (Neovim >= 0.12), which has
-- no built-in event/filetype lazy-loading. `vim.pack.add()` is cheap to call
-- eagerly (installs the plugin, defers its `plugin/`/`ftdetect/` scripts);
-- what costs boot time is a plugin's `setup()`; that's what `M.on()` defers.

local M = {}

--- Install (if needed) and register plugins without loading their
--- `plugin`/`ftdetect` scripts. Skips the install confirmation prompt.
---@param specs (string|vim.pack.Spec)[]
function M.add(specs)
  vim.pack.add(specs, { load = false, confirm = false })
end

--- Defer `opts.config()` (usually `require("plugin").setup(...)`) until one of
--- the given triggers fires. The autocmd is `once = true`, so it fires once.
---@param opts { event?: string|string[], ft?: string|string[], config: fun() }
function M.on(opts)
  if opts.ft then
    -- FileType is just an autocmd event with a pattern, so a filetype
    -- trigger is the same single `nvim_create_autocmd` call as an event one.
    vim.api.nvim_create_autocmd("FileType", { pattern = opts.ft, once = true, callback = opts.config })
  elseif opts.event then
    vim.api.nvim_create_autocmd(opts.event, { once = true, callback = opts.config })
  end
end

--- Update installed plugins via vim.pack: fetches updates and opens a
--- confirmation buffer (see `:help vim.pack`); `:write` confirms, `:quit`
--- discards, then restart to use the new code. Optional args restrict the
--- update to the named plugins.
vim.api.nvim_create_user_command("PackUpdate", function(cmd)
  local names = vim.split(vim.trim(cmd.args), "%s+", { trimempty = true })
  if #names == 0 then
    vim.pack.update()
  else
    vim.pack.update(names)
  end
end, { desc = "Update plugins (native vim.pack)", nargs = "*" })

return M
