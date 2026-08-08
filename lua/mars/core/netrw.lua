-- Native file explorer: netrw restyled as a tree-view sidebar. See
-- AGENTS.md's Native-First Philosophy: netrw already covers what a sidebar
-- file tree needs, so no plugin is added for this.

-- Netrw reads these globals the first time one of its buffers is created,
-- which happens lazily on first use, but this module loads during init
-- (see lua/mars/core/), well before that, so setting them here is early
-- enough. Kept short; each earns its place:
vim.g.netrw_liststyle = 3 -- tree-style listing instead of the flat one-name-per-line default
vim.g.netrw_banner = 0 -- drop the verbose help banner; more room for the tree itself
vim.g.netrw_winsize = -30 -- fixed 30-column sidebar rather than the default 50% of the window

--- Finds the window currently showing a netrw buffer, if any. Netrw buffers
--- keep 'buftype' empty and only identify themselves via 'filetype' (see
--- lua/mars/ui/winbar.lua for the same convention), so detection goes
--- through that rather than a buffer name pattern.
---@return integer?
local function explorer_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "netrw" then
      return win
    end
  end
  return nil
end

--- Toggles the sidebar: closes it if a netrw window is already open,
--- otherwise opens one as a left-hand vertical split. Always looks the
--- window up by filetype rather than assuming a window number, so this
--- stays correct no matter what other splits are open, and repeated
--- toggles never stack a second netrw window.
local function toggle_explorer()
  local win = explorer_win()
  if win then
    vim.api.nvim_win_close(win, false)
    return
  end
  vim.cmd.Lexplore()
end

--- Opens the sidebar rooted at the current buffer's directory. Reuses an
--- already-open sidebar in place (navigating it) instead of opening a
--- second one.
local function explore_current_file()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.uv.cwd()
  end

  local win = explorer_win()
  if win then
    vim.api.nvim_set_current_win(win)
    vim.cmd.Explore(vim.fn.fnameescape(dir))
    return
  end
  vim.cmd.Lexplore(vim.fn.fnameescape(dir))
end

vim.keymap.set("n", "<leader>e", toggle_explorer, { desc = "Explorer: toggle sidebar" })
vim.keymap.set("n", "<leader>E", explore_current_file, { desc = "Explorer: open at current file" })

-- The tree reads fine without file-type glyphs, so there's no icon table to
-- gate behind vim.g.have_nerd_font here (see AGENTS.md's Icons section);
-- this only trims window chrome the sidebar doesn't need.
local group = vim.api.nvim_create_augroup("mars_netrw", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "netrw",
  desc = "Trim window chrome the tree sidebar doesn't need",
  callback = function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.list = false
  end,
})
