-- Relative numbers + cursorline in a focused normal-mode buffer; absolute
-- numbers (no cursorline) when unfocused or in insert; nothing in special
-- buffers. Detection is heuristic (buftype + floating-window config), not a
-- filetype list, so new plugin UIs are skipped without this file updating.

--- Buftypes that mark plugin UI / special-purpose windows, never worth
--- numbering or highlighting.
local UI_BUFTYPES = {
  help = true,
  nofile = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

--- Whether the current window is a plain editable buffer: not one of
--- `UI_BUFTYPES`, not netrw, and not a float. Floats are popups (hover docs,
--- previews), never editing surfaces.
---@return boolean
local function is_normal_window()
  if UI_BUFTYPES[vim.bo.buftype] then
    return false
  end

  -- Netrw is the one UI the buftype check can't catch: its buffers keep
  -- 'buftype' empty, so it's checked by filetype here. It drives its own
  -- cursorline via g:netrw_cursor.
  if vim.bo.filetype == "netrw" then
    return false
  end

  local ok, win_config = pcall(vim.api.nvim_win_get_config, 0)
  return ok and win_config.relative == ""
end

--- Applies number/relativenumber for the current window given focus and
--- insert mode. No-ops on windows `is_normal_window` rejects.
---@param focused boolean
---@param insert boolean
local function apply_numbers(focused, insert)
  if not is_normal_window() then
    return
  end

  vim.wo.number = true
  vim.wo.relativenumber = focused and not insert
end

--- Applies cursorline for the current window given focus.
---@param focused boolean
local function apply_cursorline(focused)
  if not is_normal_window() then
    return
  end

  vim.wo.cursorline = focused
end

local augroup = vim.api.nvim_create_augroup("mars_lines", { clear = true })

vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = augroup,
  desc = "Relative numbers and cursorline for the focused window",
  callback = function()
    local insert = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
    apply_numbers(true, insert)
    apply_cursorline(true)
  end,
})

vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
  group = augroup,
  desc = "Absolute numbers and no cursorline for unfocused windows",
  callback = function()
    apply_numbers(false, false)
    apply_cursorline(false)
  end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  group = augroup,
  desc = "Absolute numbers while typing",
  callback = function()
    apply_numbers(true, true)
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = augroup,
  desc = "Relative numbers back on leaving insert mode",
  callback = function()
    apply_numbers(true, false)
  end,
})
