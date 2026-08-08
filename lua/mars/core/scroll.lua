-- Cursor-centering and smooth-scroll-feeling workaround. The felt
-- smoothness came from Snacks' scroll animation; Snacks isn't part of this
-- config (see AGENTS.md's Native-First Philosophy), so the animation itself
-- is deliberately scoped out. What's kept, and fully native, is the
-- classic `scrolloff=999` trick: forcing scrolloff very high makes Neovim's
-- own scroll logic keep the cursor vertically centered, so a half-page jump
-- lands centered instantly instead of near an edge.

-- G/n/N center the cursor line after jumping, matching the reference's
-- `Gzz`/`nzz`/`Nzz` remaps.
vim.keymap.set("n", "G", "Gzz", { desc = "Go to end of buffer and center" })
vim.keymap.set("n", "n", "nzz", { desc = "Next search match and center" })
vim.keymap.set("n", "N", "Nzz", { desc = "Previous search match and center" })

local restore_timer = nil
local saved_scrolloff = nil

--- Forces `scrolloff` very high before a half-page scroll fires, so Neovim
--- keeps the cursor vertically centered, then restores the window's real
--- `scrolloff` shortly after. The restore is debounced rather than
--- immediate: a repeated burst of <C-d>/<C-u> (e.g. holding the key) resets
--- the timer instead of restoring between keystrokes, so the centered
--- window doesn't flicker back to normal mid-burst; this is the "smooth"
--- part of the trick's feel, independent of any animation.
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
