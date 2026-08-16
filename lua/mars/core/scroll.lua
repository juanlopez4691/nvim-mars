-- Cursor-centering with the classic `scrolloff=999` trick, so a half-page
-- jump lands vertically centered. Smooth scroll animation is scoped out
-- here; only the centering is kept.

-- G/n/N center the cursor line after jumping.
vim.keymap.set("n", "G", "Gzz", { desc = "Go to end of buffer and center" })
vim.keymap.set("n", "n", "nzz", { desc = "Next search match and center" })
vim.keymap.set("n", "N", "Nzz", { desc = "Previous search match and center" })

local restore_timer = nil
local saved_scrolloff = nil

--- Forces `scrolloff` high before a half-page scroll so the cursor stays
--- vertically centered, restoring the real value shortly after. The
--- restore is debounced: a repeated burst of <C-d>/<C-u> resets the timer
--- instead of restoring between keystrokes, so the window doesn't flicker
--- mid-burst.
---@param keys string The motion to feed back to Neovim (e.g. "<C-d>").
---@return string
local function centered_scroll(keys)
  if restore_timer then
    restore_timer:close()
  else
    saved_scrolloff = vim.wo.scrolloff
  end

  vim.wo.scrolloff = 999

  restore_timer = vim.defer_fn(function()
    vim.wo.scrolloff = saved_scrolloff
    restore_timer = nil
  end, 500)

  return keys
end

vim.keymap.set("n", "<C-d>", function()
  return centered_scroll("<C-d>")
end, { expr = true, desc = "Scroll half page down and center" })

vim.keymap.set("n", "<C-u>", function()
  return centered_scroll("<C-u>")
end, { expr = true, desc = "Scroll half page up and center" })
