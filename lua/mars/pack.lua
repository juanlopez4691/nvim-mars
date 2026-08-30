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

--- Asks the user to confirm a plugin update with a native popup listing the
--- plugins. Applies by writing vim.pack's confirm buffer (its native
--- `:write`-to-apply gesture); cancelling just closes that buffer. The header
--- and `[Update]/[Cancel]` buttons stay pinned while a long list scrolls
--- in place (j/k, <C-d>/<C-u>, <C-f>/<C-b>).
---@param names string[]
---@param confirm_buf integer
---@param confirm_win integer
local function confirm_update(names, confirm_buf, confirm_win)
  local header = ("Update %d plugin%s:"):format(#names, #names == 1 and "" or "s")
  local footer = "[Update]  [Cancel]"

  local list_height = math.min(#names, math.max(vim.o.lines - 10, 3))
  local height = list_height + 4

  local width = math.max(#header, #footer)
  for _, n in ipairs(names) do
    width = math.max(width, #n + 2)
  end
  width = math.min(width + 2, vim.o.columns - 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max((vim.o.lines - height) / 2, 0),
    col = math.max((vim.o.columns - width) / 2, 0),
    style = "minimal",
    border = "rounded",
  })

  local offset = 0
  local function render()
    local lines = { header, "" }
    for i = 1, list_height do
      local idx = offset + i
      lines[#lines + 1] = idx <= #names and ("  " .. names[idx]) or ""
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = footer
    -- nvim_buf_set_lines respects 'modifiable', so toggle around the rewrite
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end
  render()

  local function scroll(delta)
    offset = math.max(0, math.min(#names - list_height, offset + delta))
    render()
  end

  local function close_popup()
    vim.api.nvim_win_close(win, true)
  end

  local function cancel()
    close_popup()
    vim.api.nvim_win_close(confirm_win, true)
  end

  vim.keymap.set("n", "<CR>", function()
    close_popup()
    vim.api.nvim_buf_call(confirm_buf, function()
      vim.cmd.write()
    end)
  end, { buffer = buf, nowait = true, desc = "Update" })
  vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true, desc = "Cancel" })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true })

  local half_page = math.max(math.floor(list_height / 2), 1)
  local function bind(key, delta)
    vim.keymap.set("n", key, function()
      scroll(delta)
    end, { buffer = buf, nowait = true })
  end
  bind("j", 1)
  bind("k", -1)
  bind("<C-d>", half_page)
  bind("<C-u>", -half_page)
  bind("<C-f>", list_height)
  bind("<C-b>", -list_height)
end

--- Updates installed plugins via vim.pack, replacing its full-screen
--- confirmation buffer with a compact popup. Optional args restrict the update
--- to the named plugins.
vim.api.nvim_create_user_command("PackUpdate", function(cmd)
  local names = vim.split(vim.trim(cmd.args), "%s+", { trimempty = true })
  local user_win = vim.api.nvim_get_current_win()
  vim.pack.update(#names > 0 and names or nil)

  local buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_get_name(buf):match("^nvim%-pack://confirm") then
    return
  end

  -- Collect the plugins under the "# Update" section; errors keep the native
  -- screen so they stay visible.
  local to_update, in_update, errored = {}, false, false
  for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local name = l:match("^## (.+)$")
    if name and in_update then
      to_update[#to_update + 1] = name:gsub(" %(not active%)$", "")
    end
    local group = l:match("^# (%S+)")
    if group == "Update" then
      in_update = true
    elseif group == "Error" then
      errored = true
    elseif group == "Same" then
      in_update = false
    end
  end

  if errored or #to_update == 0 then
    if #to_update == 0 and not errored then
      vim.api.nvim_win_close(0, true)
      vim.notify("All plugins up to date")
    end
    return
  end

  local confirm_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(user_win)
  confirm_update(to_update, buf, confirm_win)
end, { desc = "Update plugins (native vim.pack)", nargs = "*" })

-- `PackChanged` fires once per applied update; debounce into a single
-- notification listing which plugins were updated.
local updated = {}
local notify_timer

vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.kind ~= "update" then
      return
    end
    updated[#updated + 1] = ev.data.spec.name
    if notify_timer then
      notify_timer:stop()
    end
    notify_timer = vim.defer_fn(function()
      notify_timer = nil
      vim.notify(("Updated %d plugin%s: %s"):format(#updated, #updated == 1 and "" or "s", table.concat(updated, ", ")))
      updated = {}
    end, 500)
  end,
})

return M
