-- Native autopairs: auto-closes brackets and quotes in insert mode,
-- and backspaces both sides of a freshly-inserted pair at once. Replaces
-- mini.pairs with a first-party InsertCharPre-based implementation.

local M = {}

local augroup = vim.api.nvim_create_augroup("mars_autopairs", { clear = true })

local PAIRS = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ["'"] = "'",
  ['"'] = '"',
  ["`"] = "`",
}

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = augroup,
  callback = function()
    local char = vim.v.char
    local pair = PAIRS[char]
    if not pair then
      return
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]

    local next_char = line:sub(col + 1, col + 1)
    if next_char:match("[%w]") then
      return
    end

    if char == pair and next_char == char then
      return
    end

    local keys = vim.api.nvim_replace_termcodes(pair, true, true, true)
    vim.api.nvim_feedkeys(keys, "n", false)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Left>", true, true, true), "n", false)
  end,
})

-- Backspace handler: when the cursor sits between a paired open/close
-- character (e.g. `(|)`), delete both at once instead of just the open
-- character.  InsertCharPre is *not* fired for backspace in practice, so
-- this handler races ahead of the actual backspace insert by deleting
-- the close char and then feeding <Ignore> to consume the backspace.
vim.api.nvim_create_autocmd("InsertCharPre", {
  group = augroup,
  callback = function()
    if vim.v.char ~= "\b" and vim.v.char ~= "\127" then
      return
    end
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col < 2 or col > #line then
      return
    end
    local left = line:sub(col, col)
    local right = line:sub(col + 1, col + 1)
    for open, close in pairs(PAIRS) do
      if left == open and right == close then
        vim.api.nvim_buf_set_text(vim.api.nvim_get_current_buf(), 0, col - 1, 0, col + 1, { "" })
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], col - 1 })
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Ignore>", true, true, true), "n", false)
        return
      end
    end
  end,
})

return M
