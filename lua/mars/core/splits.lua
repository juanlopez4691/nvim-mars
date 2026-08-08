-- Directional split navigation and resize, reproducing vim-tmux-navigator's
-- Ctrl-hjkl wrapping and an edge-aware Alt-arrow resize natively (see
-- AGENTS.md's Native-First Philosophy); both are a handful of `wincmd`/
-- `resize` calls plus a screen-edge check, not worth a plugin dependency.

--- Opposite direction for each `wincmd` motion, used to wrap focus around
--- to the far edge when a jump in the primary direction didn't move focus
--- at all (i.e. the current split is already at that screen edge).
local OPPOSITE = { h = "l", l = "h", j = "k", k = "j" }

--- Filetypes that are plugin UI panes where resizing doesn't make sense:
--- the netrw sidebar (fixed-width tree, see lua/mars/core/netrw.lua) and
--- nvim-dap-ui's element windows plus nvim-dap's own REPL buffer (fixed
--- layout panes, see lua/mars/plugins/dap.lua and nvim-dap-ui's element
--- sources under lua/dapui/elements/*.lua for these exact filetype
--- strings).
local SKIP_FILETYPES = {
  netrw = true,
  dapui_scopes = true,
  dapui_breakpoints = true,
  dapui_stacks = true,
  dapui_watches = true,
  dapui_console = true,
  dapui_hover = true,
  ["dap-repl"] = true,
}

--- Buftypes that are plugin/native UI panes where resizing doesn't make
--- sense. Quickfix and location-list windows share buftype "quickfix" (see
--- lua/mars/core/diagnostics.lua, which populates both via
--- setqflist/setloclist), so this alone covers both.
local SKIP_BUFTYPES = {
  quickfix = true,
}

--- How many rows/columns a single resize keypress grows or shrinks a
--- split by.
local RESIZE_AMOUNT = 2

--- Whether the current window's right edge touches the screen's right
--- edge.
---@param win integer
---@return boolean
local function is_rightmost(win)
  local pos = vim.api.nvim_win_get_position(win)
  return pos[2] + vim.api.nvim_win_get_width(win) >= vim.o.columns
end

--- Whether the current window's bottom edge touches the screen's bottom
--- edge, accounting for the command line.
---@param win integer
---@return boolean
local function is_bottommost(win)
  local pos = vim.api.nvim_win_get_position(win)
  return pos[1] + vim.api.nvim_win_get_height(win) >= vim.o.lines - vim.o.cmdheight - 1
end

--- Runs `wincmd` toward `direction`, `count` times, and reports whether
--- focus actually moved to a different window; it won't if the current
--- split is already at that screen edge.
---@param direction "h"|"j"|"k"|"l"
---@param count integer
---@return boolean moved
local function try_move(direction, count)
  local before = vim.fn.winnr()
  vim.cmd(("%d wincmd %s"):format(count, direction))
  return vim.fn.winnr() ~= before
end

--- Moves focus one split toward `direction`, wrapping around to the split
--- at the opposite screen edge (vim-tmux-navigator style) when `direction`
--- didn't move focus at all. A count applies to the primary move; the
--- wrap-around jump always goes all the way to the far edge, mirroring how
--- moving off one screen edge lands on the other.
---@param direction "h"|"j"|"k"|"l"
local function move(direction)
  if not try_move(direction, vim.v.count1) then
    try_move(OPPOSITE[direction], 999)
  end
end

--- Whether the current window is one of the plugin UI panes resizing
--- should skip (see SKIP_FILETYPES/SKIP_BUFTYPES above). Read at call time
--- rather than memoized, since it depends on whichever window/buffer is
--- current when a resize keymap fires.
---@return boolean
local function skip_resize()
  return SKIP_FILETYPES[vim.bo.filetype] or SKIP_BUFTYPES[vim.bo.buftype] or false
end

--- Resizes the current split toward `direction`, growing or shrinking
--- depending on which screen edge the split is already on so the visual
--- result always matches intuition; e.g. "resize right" grows a split on
--- the left half of the screen but shrinks one on the right half, since
--- there's no room on its right to grow into. No-ops on plugin UI panes
--- where resizing doesn't make sense (see skip_resize).
---@param direction "left"|"right"|"up"|"down"
local function resize(direction)
  if skip_resize() then
    return
  end

  local win = vim.api.nvim_get_current_win()

  if direction == "left" or direction == "right" then
    local grow = (direction == "right") ~= is_rightmost(win)
    vim.cmd(("vertical resize %s%d"):format(grow and "+" or "-", RESIZE_AMOUNT))
  else
    local grow = (direction == "down") ~= is_bottommost(win)
    vim.cmd(("resize %s%d"):format(grow and "+" or "-", RESIZE_AMOUNT))
  end
end

vim.keymap.set("n", "<C-h>", function()
  move("h")
end, { silent = true, desc = "Window: focus left, wrapping" })
vim.keymap.set("n", "<C-j>", function()
  move("j")
end, { silent = true, desc = "Window: focus down, wrapping" })
vim.keymap.set("n", "<C-k>", function()
  move("k")
end, { silent = true, desc = "Window: focus up, wrapping" })
vim.keymap.set("n", "<C-l>", function()
  move("l")
end, { silent = true, desc = "Window: focus right, wrapping" })

for _, key in ipairs({ "<A-Left>", "<C-A-h>" }) do
  vim.keymap.set("n", key, function()
    resize("left")
  end, { silent = true, desc = "Window: resize left" })
end
for _, key in ipairs({ "<A-Right>", "<C-A-l>" }) do
  vim.keymap.set("n", key, function()
    resize("right")
  end, { silent = true, desc = "Window: resize right" })
end
for _, key in ipairs({ "<A-Up>", "<C-A-k>" }) do
  vim.keymap.set("n", key, function()
    resize("up")
  end, { silent = true, desc = "Window: resize up" })
end
for _, key in ipairs({ "<A-Down>", "<C-A-j>" }) do
  vim.keymap.set("n", key, function()
    resize("down")
  end, { silent = true, desc = "Window: resize down" })
end
