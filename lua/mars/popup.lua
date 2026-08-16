-- Centered, dismissible floating window for showing read-only content

local M = {}

--- Shows `lines` in a centered float with a border; `q`/`<Esc>` close it.
---@param lines string[]
---@param opts? { title?: string, pad?: integer } Horizontal padding added on
---  each side of every line, default 0.
function M.show(lines, opts)
  opts = opts or {}
  local pad = string.rep(" ", opts.pad or 0)
  local padded = {}
  for i, line in ipairs(lines) do
    padded[i] = pad .. line .. pad
  end

  local width = 0
  for _, line in ipairs(padded) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  -- The `+2` keeps the widest line clear of the right border.
  width = width + 2
  -- Cap the height to the terminal so a small window can't push the float
  -- off-screen.
  local height = math.min(#padded, math.max(10, vim.o.lines - 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, padded)
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width + 2,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - (height + 2)) / 2)),
    col = math.max(0, math.floor((vim.o.columns - (width + 2)) / 2)),
    style = "minimal",
    border = require("mars.ui.borders").style(),
    title = opts and opts.title,
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf })
end

return M
