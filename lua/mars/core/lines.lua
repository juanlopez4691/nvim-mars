-- Toggles absolute-vs-relative line numbers and the cursorline per mode and
-- window focus: relative numbers + cursorline in a focused, editable buffer
-- in normal mode; absolute numbers (no cursorline) when unfocused or in
-- insert mode; nothing at all in special buffers (floats, terminals,
-- quickfix, help, prompts, ...).
--
-- Detection is heuristic (buftype + floating-window config) rather than a
-- hardcoded filetype list, so new plugin UIs (dap-ui, opencode's terminal,
-- ...) are skipped automatically without this file needing an update.

local M = {}

--- Buftypes that mark a window as plugin UI / special-purpose, never worth
--- numbering or highlighting the cursor line in.
local UI_BUFTYPES = {
  help = true,
  nofile = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

--- Whether the current window is a plain, editable buffer worth managing:
--- not one of `UI_BUFTYPES`, and not a floating/popup window (relative ~=
--- ""). Floats never get numbers/cursorline regardless of what they hold,
--- since they're popups (hover docs, previews, ...) rather than editing
--- surfaces.
---@return boolean
local function is_normal_window()
  if UI_BUFTYPES[vim.bo.buftype] then
    return false
  end

  local ok, win_config = pcall(vim.api.nvim_win_get_config, 0)
  return ok and win_config.relative == ""
end

--- Applies numbers/relativenumber for the current window, given whether it
--- is focused and whether it's currently in insert mode. No-ops on windows
--- `is_normal_window` rejects, leaving their number columns untouched.
---@param focused boolean
---@param insert boolean
local function apply_numbers(focused, insert)
  if not is_normal_window() then
    return
  end

  vim.wo.number = true
  vim.wo.relativenumber = focused and not insert
end

--- Applies cursorline for the current window, given whether it is focused.
--- No-ops on windows `is_normal_window` rejects.
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

return M
