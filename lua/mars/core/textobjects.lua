-- Enhanced text objects: native replacements for mini.ai, function-call
-- text objects (`if`/`af`, treesitter-driven) and entire-buffer objects
-- (`iB`/`aB`) in operator-pending and visual modes.

---@param around boolean true for "around" (includes trailing paren)
local function select_function_call(around)
  local node = vim.treesitter.get_node()
  if not node then
    return
  end
  while node do
    if node:type() == "function_call" or node:type() == "method_call" or node:type() == "call_expression" then
      local start_row, start_col, end_row, end_col = node:range()
      if around then
        vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col - 1 })
      else
        local args_node
        for child in node:iter_children() do
          if child:type() == "arguments" then
            args_node = child
            break
          end
        end
        if args_node then
          local as, _, ae, _ = args_node:range()
          vim.api.nvim_win_set_cursor(0, { as + 1, ae - 1 })
          vim.cmd("normal! v")
          vim.api.nvim_win_set_cursor(0, { as + 1, as + 1 })
        else
          vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
          vim.cmd("normal! v")
          vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col - 1 })
        end
      end
      return
    end
    node = node:parent()
  end
end

local function select_buffer(around)
  local last_line = vim.api.nvim_buf_line_count(0)
  local last_col = #vim.api.nvim_buf_get_lines(0, last_line - 1, last_line, false)[1]
  if around then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, { last_line, last_col })
  else
    local first, last = 1, last_line
    while first <= last_line and vim.api.nvim_buf_get_lines(0, first - 1, first, false)[1]:match("^%s*$") do
      first = first + 1
    end
    while last >= 1 and vim.api.nvim_buf_get_lines(0, last - 1, last, false)[1]:match("^%s*$") do
      last = last - 1
    end
    vim.api.nvim_win_set_cursor(0, { first, 0 })
    vim.cmd("normal! v")
    local last_line_text = vim.api.nvim_buf_get_lines(0, last - 1, last, false)[1]
    vim.api.nvim_win_set_cursor(0, { last, #last_line_text })
  end
end

vim.keymap.set("o", "if", function()
  select_function_call(false)
end, { silent = true, desc = "Inner function call" })
vim.keymap.set("o", "af", function()
  select_function_call(true)
end, { silent = true, desc = "Around function call" })
vim.keymap.set("o", "iB", function()
  select_buffer(false)
end, { silent = true, desc = "Inner buffer" })
vim.keymap.set("o", "aB", function()
  select_buffer(true)
end, { silent = true, desc = "Around buffer" })
vim.keymap.set("x", "if", function()
  select_function_call(false)
end, { silent = true, desc = "Inner function call" })
vim.keymap.set("x", "af", function()
  select_function_call(true)
end, { silent = true, desc = "Around function call" })
vim.keymap.set("x", "iB", function()
  select_buffer(false)
end, { silent = true, desc = "Inner buffer" })
vim.keymap.set("x", "aB", function()
  select_buffer(true)
end, { silent = true, desc = "Around buffer" })
