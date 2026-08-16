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

--- Re-hosts vim.pack's update-confirmation buffer, normally opened in a new
--- tab, into a centered float. The apply-on-`:write` logic stays bound to
--- the buffer (BufWriteCmd), so confirming in the popup updates plugins
--- exactly like the native tab.
---@param names string[]
---@return boolean ok
local function update_in_popup(names)
  -- vim.pack attaches a WinClosed handler to its confirmation tab; remember
  -- the existing ones so that one can be dropped before closing the tab.
  local known = {}
  for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "WinClosed" })) do
    known[au.id] = true
  end

  local ok, err = pcall(vim.pack.update, names)
  if not ok then
    vim.notify(("Pack update failed: %s"):format(err), vim.log.levels.ERROR)
    return false
  end

  -- vim.pack.update() opened its confirmation buffer in a new tab.
  local confirm_buf
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "nvim-pack" and vim.fn.bufname(buf):match("nvim%-pack://confirm") then
      confirm_buf = buf
      break
    end
  end
  if not confirm_buf then
    return true -- nothing to update; vim.pack already notified
  end

  -- Drop the WinClosed handler vim.pack attached to its tab window, so
  -- closing that tab can't delete the buffer we're about to float.
  for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "WinClosed" })) do
    if not known[au.id] then
      pcall(vim.api.nvim_del_autocmd, au.id)
    end
  end

  vim.cmd.tabclose() -- leave vim.pack's tab; the buffer survives

  local lines = vim.api.nvim_buf_get_lines(confirm_buf, 0, -1, false)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local height = math.min(#lines, math.max(10, vim.o.lines - 2))

  local win = vim.api.nvim_open_win(confirm_buf, true, {
    relative = "editor",
    width = width + 2,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - (height + 2)) / 2)),
    col = math.max(0, math.floor((vim.o.columns - (width + 2)) / 2)),
    style = "minimal",
    border = require("mars.ui.borders").style(),
    title = "Pack update  ·  y apply  /  q discard",
  })

  local function cancel()
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, confirm_buf, { force = true })
  end
  vim.keymap.set("n", "q", cancel, { buffer = confirm_buf })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = confirm_buf })

  -- Fire the buffer's own BufWriteCmd directly: `:write` on an acwrite
  -- buffer with a buffer-local callback autocmd raises E676 in this Neovim
  -- build, but the autocmd carries the apply logic either way. It applies
  -- the updates and tears the buffer down; the popup closes right after.
  local function confirm()
    vim.api.nvim_exec_autocmds("BufWriteCmd", { buffer = confirm_buf })
    pcall(vim.api.nvim_win_close, win, true)
  end
  vim.keymap.set("n", "y", confirm, { buffer = confirm_buf })
  vim.keymap.set("n", "<CR>", confirm, { buffer = confirm_buf })

  return true
end

--- Update installed plugins via vim.pack: fetches updates and opens a
--- confirmation popup (`y` applies, `q`/`<Esc>` discards), then restart to
--- use the new code. Optional args restrict the update to the named plugins.
vim.api.nvim_create_user_command("PackUpdate", function(cmd)
  local names = vim.split(vim.trim(cmd.args), "%s+", { trimempty = true })
  update_in_popup(names)
end, { desc = "Update plugins (native vim.pack)", nargs = "*" })

return M
