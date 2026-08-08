--- Applies the built-in `default` colorscheme plus a handful of highlight
--- tweaks that the base palette doesn't quite get right on its own.

--- Overrides applied on top of the active colorscheme. Kept intentionally
--- small: each entry only exists because the base groups it touches are
--- either identical when they shouldn't be, or louder than their role
--- warrants.
local function apply_overrides()
  -- Window separators default to the same weight as body text, which gets
  -- noisy once more than one or two splits are open. Read them as UI chrome
  -- instead.
  vim.api.nvim_set_hl(0, "WinSeparator", { link = "NonText" })

  -- WinBar and WinBarNC render identically out of the box, so a split's
  -- focus isn't visible from its bar alone. Make the focused window's bar
  -- read as regular text, and let the unfocused one recede the same way an
  -- inactive statusline already does.
  vim.api.nvim_set_hl(0, "WinBar", { link = "Normal" })
  vim.api.nvim_set_hl(0, "WinBarNC", { link = "StatusLineNC" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Reapply Mars highlight overrides after the colorscheme (re)loads",
  group = vim.api.nvim_create_augroup("mars_colorscheme", { clear = true }),
  callback = apply_overrides,
})

vim.cmd.colorscheme("default")
