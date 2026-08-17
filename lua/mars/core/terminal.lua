-- Generic shell terminals under `<leader>t` (the which-key "Terminal" group):
-- `<leader>tt` toggles a horizontal split across the bottom, `<leader>tv` a
-- vertical split down the right, each its own independent terminal. Sizes
-- default to 40% and are configurable via `vim.g.mars_split_terminal_size`
-- (e.g. `{ height = 0.5, width = 0.45 }`). A count opens another stacked
-- terminal (`2<leader>tt`).

local term = require("mars.helpers.term")

---@return string[]
local function shell_cmd()
  return { vim.o.shell }
end

local function project_root()
  return vim.fs.root(0, ".git") or vim.uv.cwd()
end

--- Size fractions read at call time so local.lua overrides apply.
---@return { height?: number, width?: number }
local function size()
  return type(vim.g.mars_split_terminal_size) == "table" and vim.g.mars_split_terminal_size or {}
end

---@return vim.api.keyset.win_config
local function horizontal_geometry()
  local s = size()
  return {
    split = "below",
    win = -1,
    height = math.floor(vim.o.lines * (s.height or 0.4)),
  }
end

---@return vim.api.keyset.win_config
local function vertical_geometry()
  local s = size()
  return {
    split = "right",
    win = -1,
    width = math.floor(vim.o.columns * (s.width or 0.4)),
  }
end

--- `id` keeps the two layouts distinct terminals in the shared manager.
local function toggle(id, win_config)
  term.toggle({ id = id, cmd = shell_cmd(), cwd = project_root(), win_config = win_config })
end

vim.keymap.set("n", "<leader>tt", function()
  toggle("h", horizontal_geometry())
end, { desc = "Toggle horizontal terminal" })

vim.keymap.set("n", "<leader>tv", function()
  toggle("v", vertical_geometry())
end, { desc = "Toggle vertical terminal" })

vim.api.nvim_create_user_command("MarsTerminal", function()
  toggle("h", horizontal_geometry())
end, { desc = "Toggle the horizontal terminal (bottom split)" })
