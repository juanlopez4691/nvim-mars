--- Applies the built-in `default` colorscheme plus highlight tweaks the
--- base palette doesn't get right on its own.

--- Highlight overrides applied on top of the active colorscheme.
local function apply_overrides()
  -- Separators match body-text weight; read them as chrome instead.
  vim.api.nvim_set_hl(0, "WinSeparator", { link = "NonText" })

  -- WinBar and WinBarNC look identical; differentiate focus like the statusline does.
  vim.api.nvim_set_hl(0, "WinBar", { link = "Normal" })
  vim.api.nvim_set_hl(0, "WinBarNC", { link = "StatusLineNC" })

  -- pumborder defaults to Pmenu fg on editor bg (loud, haloed); use chrome on the pum's own bg.
  local pmenu = vim.api.nvim_get_hl(0, { name = "Pmenu" })
  local chrome = vim.api.nvim_get_hl(0, { name = "NonText" })
  vim.api.nvim_set_hl(0, "PmenuBorder", { fg = chrome.fg, bg = pmenu.bg })

  -- Float borders default to editor bg, haloing darker float content; paint
  -- them chrome on the float's own bg (NormalFloat links to Pmenu).
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = chrome.fg, bg = pmenu.bg })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Reapply Mars highlight overrides after the colorscheme (re)loads",
  group = vim.api.nvim_create_augroup("mars_colorscheme", { clear = true }),
  callback = apply_overrides,
})

vim.cmd.colorscheme("default")
