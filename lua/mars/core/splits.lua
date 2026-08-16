-- Directional split navigation (vim-tmux-navigator-style wrapping) and
-- edge-aware Alt-arrow resize, both natively via `wincmd`/`resize`.

--- Opposite direction for each `wincmd` motion, used to wrap focus to the
--- far edge when a jump didn't move it at all.
local OPPOSITE = { h = "l", l = "h", j = "k", k = "j" }

--- Filetypes that are plugin UI panes where resizing makes no sense.
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

--- Buftypes that are plugin/native UI panes where resizing makes no sense.
--- Quickfix and location lists share buftype "quickfix", so this covers
--- both.
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

--- Runs `wincmd` toward `direction`, `count` times, reporting whether
--- focus actually moved (it won't if already at that screen edge).
---@param direction "h"|"j"|"k"|"l"
---@param count integer
---@return boolean moved
local function try_move(direction, count)
  local before = vim.fn.winnr()
  vim.cmd(("%d wincmd %s"):format(count, direction))
  return vim.fn.winnr() ~= before
end

--- Moves focus one split toward `direction`, wrapping to the opposite
--- screen edge when it didn't move at all. A count applies to the primary
--- move; the wrap jump always goes all the way to the far edge.
---@param direction "h"|"j"|"k"|"l"
local function move(direction)
  if not try_move(direction, vim.v.count1) then
    try_move(OPPOSITE[direction], 999)
  end
end

--- Whether the current window is a UI pane resizing should skip (see
--- SKIP_FILETYPES/SKIP_BUFTYPES). Read at call time, since it depends on
--- the window/buffer current when the keymap fires.
---@return boolean
local function skip_resize()
  return SKIP_FILETYPES[vim.bo.filetype] or SKIP_BUFTYPES[vim.bo.buftype] or false
end

--- Resizes the current split toward `direction`, growing or shrinking
--- depending on which screen edge it's on so the result matches intuition
--- ("resize right" grows a split on the left half but shrinks one on the
--- right, which has no room to grow). No-ops on UI panes (see skip_resize).
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

--- Re-equalizes splits after the terminal resizes: Neovim's proportional
--- rescale drifts, and every tabpage is equalized since background tabs
--- were laid out at the old size. `nvim_win_call` scopes `wincmd =` to each
--- tabpage without `tabdo` side effects (WinEnter/BufEnter firing, the
--- alternate tab being clobbered). Windows with 'winfixwidth'/'winfixheight'
--- (netrw sidebar, dap-ui panes) keep their size.
local function equalize()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    vim.api.nvim_win_call(vim.api.nvim_tabpage_get_win(tab), function()
      vim.cmd("wincmd =")
    end)
  end
end

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("mars_splits", { clear = true }),
  desc = "Re-equalize splits when the terminal is resized",
  callback = equalize,
})

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

-- The <C-w> split/close commands under <leader>w; the suffix letter matches
-- the <C-w> one (<leader>wv = :vsplit = <C-w>v), for a thumb-reachable
-- second way to run them. The native <C-w> maps are left untouched.
for suffix, spec in pairs({
  v = { cmd = "vsplit", desc = "Window: split vertically" },
  s = { cmd = "split", desc = "Window: split horizontally" },
  n = { cmd = "new", desc = "Window: new empty split" },
  c = { cmd = "close", desc = "Window: close current split" },
  o = { cmd = "only", desc = "Window: close other splits" },
  q = { cmd = "quit", desc = "Window: quit current split" },
}) do
  vim.keymap.set("n", "<leader>w" .. suffix, ("<Cmd>%s<CR>"):format(spec.cmd), {
    silent = true,
    desc = spec.desc,
  })
end
vim.keymap.set("n", "<leader>w=", equalize, { silent = true, desc = "Window: equalize splits" })
