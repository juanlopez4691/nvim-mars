-- Native vim-surround core: `ds{char}`, `cs{old}{new}`, `ys{motion}{char}`,
-- `yss{char}`, visual `S{char}`. Brackets matched with searchpairpos()
-- (nesting-aware, spans lines); quotes scanned on the current line only;
-- they don't nest, so there's no well-defined multi-line partner. Padding
-- follows vim-surround: an opening bracket variant pads the inside; the
-- closing variant or a quote inserts tight.

local M = {}

--- Bracket pairs, keyed by either the opening or closing character so
--- `ds)`/`ds(`, `cs])`/`cs)]`, etc. all resolve to the same pair.
---@type table<string, {open: string, close: string}>
local BRACKETS = {
  ["("] = { open = "(", close = ")" },
  [")"] = { open = "(", close = ")" },
  ["["] = { open = "[", close = "]" },
  ["]"] = { open = "[", close = "]" },
  ["{"] = { open = "{", close = "}" },
  ["}"] = { open = "{", close = "}" },
}

--- The opening variant of each supported bracket char, used to decide
--- whether a target character should pad its surround with a space.
---@type table<string, boolean>
local OPENING_BRACKET = { ["("] = true, ["["] = true, ["{"] = true }

--- Supported quote characters.
---@type table<string, boolean>
local QUOTES = { ['"'] = true, ["'"] = true, ["`"] = true }

--- Vim-regex pattern per bracket. `(`/`)`/`{`/`}` are literal under 'magic';
--- `[` starts a character class, so it and `]` are escaped.
---@type table<string, string>
local BRACKET_PATTERN = {
  ["("] = "(",
  [")"] = ")",
  ["["] = "\\[",
  ["]"] = "\\]",
  ["{"] = "{",
  ["}"] = "}",
}

--- A single delimiter position, matching `nvim_buf_get_mark`'s convention:
--- 1-indexed row, 0-indexed byte column.
---@class Mars.Surround.Pos
---@field [1] integer row (1-indexed)
---@field [2] integer col (0-indexed)

--- Finds the innermost `open`/`close` bracket pair enclosing the cursor via
--- searchpairpos(), or nil. Converts its 1-indexed columns to 0-indexed.
---@param open string
---@param close string
---@return Mars.Surround.Pos|nil open_pos
---@return Mars.Surround.Pos|nil close_pos
local function find_bracket_pair(open, close)
  local open_pat, close_pat = BRACKET_PATTERN[open], BRACKET_PATTERN[close]
  local saved_view = vim.fn.winsaveview()

  local open_pos = vim.fn.searchpairpos(open_pat, "", close_pat, "bcnW")
  if open_pos[1] == 0 then
    vim.fn.winrestview(saved_view)
    return nil, nil
  end

  vim.fn.cursor(open_pos[1], open_pos[2])
  local close_pos = vim.fn.searchpairpos(open_pat, "", close_pat, "nW")
  vim.fn.winrestview(saved_view)

  if close_pos[1] == 0 then
    return nil, nil
  end
  return { open_pos[1], open_pos[2] - 1 }, { close_pos[1], close_pos[2] - 1 }
end

--- Finds the `quote` pair on the current line enclosing the cursor or the
--- next one at/after it, skipping escaped quotes. Same line only: see
--- the module doc.
---@param quote string
---@return integer|nil open_col 0-indexed
---@return integer|nil close_col 0-indexed
local function find_quote_pair(quote)
  local line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2]

  local positions = {}
  local i = 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" then
      i = i + 2
    else
      if c == quote then
        table.insert(positions, i)
      end
      i = i + 1
    end
  end

  for k = 1, #positions - 1, 2 do
    local open_col, close_col = positions[k] - 1, positions[k + 1] - 1
    if close_col >= cursor_col then
      return open_col, close_col
    end
  end
  return nil, nil
end

--- Resolves `char` to the open/close positions of its surrounding pair, or
--- nil (with a warning) if unsupported or nothing encloses the cursor.
---@param char string
---@return Mars.Surround.Pos|nil open_pos
---@return Mars.Surround.Pos|nil close_pos
local function resolve_pair(char)
  if QUOTES[char] then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local open_col, close_col = find_quote_pair(char)
    if not open_col then
      return nil, nil
    end
    return { row, open_col }, { row, close_col }
  end

  local pair = BRACKETS[char]
  if not pair then
    vim.notify(("surround: no pair found for %q"):format(char), vim.log.levels.WARN)
    return nil, nil
  end

  local open_pos, close_pos = find_bracket_pair(pair.open, pair.close)
  if not open_pos then
    vim.notify(("surround: no enclosing %q pair found"):format(char), vim.log.levels.WARN)
    return nil, nil
  end
  return open_pos, close_pos
end

--- Literal open/close delimiters for `char` as a new surround target.
--- Opening bracket variants pad the inside; anything else inserts as-is.
---@param char string
---@return string|nil open_delim
---@return string|nil close_delim
local function delimiters_for(char)
  local pair = BRACKETS[char]
  if pair then
    if OPENING_BRACKET[char] then
      return pair.open .. " ", " " .. pair.close
    end
    return pair.open, pair.close
  end

  if #char == 1 then
    return char, char
  end
  return nil, nil
end

--- Deletes the single character at `pos`.
---@param pos Mars.Surround.Pos
local function delete_char_at(pos)
  local row, col = pos[1] - 1, pos[2]
  vim.api.nvim_buf_set_text(0, row, col, row, col + 1, {})
end

--- Replaces the single character at `pos` with `text`.
---@param pos Mars.Surround.Pos
---@param text string
local function replace_char_at(pos, text)
  local row, col = pos[1] - 1, pos[2]
  vim.api.nvim_buf_set_text(0, row, col, row, col + 1, { text })
end

--- `ds{char}`. Deletes the close side first so the open position stays valid.
---@param char string
local function delete_surround(char)
  local open_pos, close_pos = resolve_pair(char)
  if not open_pos then
    return
  end
  delete_char_at(close_pos)
  delete_char_at(open_pos)
end

--- `cs{old}{new}`: swaps the surrounding pair identified by `old` for the
--- delimiters of `new`, leaving any existing inner padding untouched.
---@param old string
---@param new_char string
local function change_surround(old, new_char)
  local open_pos, close_pos = resolve_pair(old)
  if not open_pos then
    return
  end

  local new_open, new_close
  local bracket = BRACKETS[new_char]
  if bracket then
    new_open, new_close = bracket.open, bracket.close
  elseif #new_char == 1 then
    new_open, new_close = new_char, new_char
  else
    vim.notify(("surround: unsupported replacement %q"):format(new_char), vim.log.levels.WARN)
    return
  end

  replace_char_at(close_pos, new_close)
  replace_char_at(open_pos, new_open)
end

--- Inserts `open_delim`/`close_delim` around the charwise span from
--- `start_pos` to `end_pos` (both `nvim_buf_get_mark`-style: 1-indexed
--- row, 0-indexed col; `end_pos` is the last included character).
---@param start_pos Mars.Surround.Pos
---@param end_pos Mars.Surround.Pos
---@param open_delim string
---@param close_delim string
local function wrap_charwise(start_pos, end_pos, open_delim, close_delim)
  local srow, scol = start_pos[1] - 1, start_pos[2]
  local erow, ecol = end_pos[1] - 1, end_pos[2]

  vim.api.nvim_buf_set_text(0, erow, ecol + 1, erow, ecol + 1, { close_delim })
  vim.api.nvim_buf_set_text(0, srow, scol, srow, scol, { open_delim })
end

--- Inserts `open_delim`/`close_delim` tightly around a linewise span (first
--- non-blank through last non-blank). Used by `yss`/visual linewise `S` and
--- linewise operator motions. Unlike vim-surround's `yS`, never re-indents
--- the delimiters onto their own lines.
---@param start_pos Mars.Surround.Pos
---@param end_pos Mars.Surround.Pos
---@param open_delim string
---@param close_delim string
local function wrap_linewise(start_pos, end_pos, open_delim, close_delim)
  local srow, erow = start_pos[1], end_pos[1]
  local first_line = vim.api.nvim_buf_get_lines(0, srow - 1, srow, true)[1]
  local last_line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, true)[1]

  local scol = (first_line:find("%S") or 1) - 1
  local trimmed_last = last_line:gsub("%s+$", "")
  local ecol = math.max(#trimmed_last - 1, 0)

  wrap_charwise({ srow, scol }, { erow, ecol }, open_delim, close_delim)
end

--- Prompts for the target char via getcharstr(), resolving its delimiters.
--- Returns nil on cancel or an unsupported char.
---@return string|nil open_delim
---@return string|nil close_delim
local function prompt_delimiters()
  local ok, char = pcall(vim.fn.getcharstr)
  if not ok or char == "" or char == "\27" then
    return nil, nil
  end

  local open_delim, close_delim = delimiters_for(char)
  if not open_delim then
    vim.notify(("surround: unsupported target %q"):format(char), vim.log.levels.WARN)
    return nil, nil
  end
  return open_delim, close_delim
end

--- `operatorfunc` target for `ys{motion}`: reads the `'[`/`']` marks the
--- motion left and prompts for the surround char.
---@param motion_type "line"|"char"|"block"
function M.opfunc(motion_type)
  local open_delim, close_delim = prompt_delimiters()
  if not open_delim then
    return
  end

  local start_pos = vim.api.nvim_buf_get_mark(0, "[")
  local end_pos = vim.api.nvim_buf_get_mark(0, "]")

  if motion_type == "line" then
    wrap_linewise(start_pos, end_pos, open_delim, close_delim)
  else
    wrap_charwise(start_pos, end_pos, open_delim, close_delim)
  end
end

vim.keymap.set("n", "ds", function()
  local ok, char = pcall(vim.fn.getcharstr)
  if ok and char ~= "" and char ~= "\27" then
    delete_surround(char)
  end
end, { desc = "Delete Surround" })

vim.keymap.set("n", "cs", function()
  local ok, old = pcall(vim.fn.getcharstr)
  if not ok or old == "" or old == "\27" then
    return
  end
  local ok2, new_char = pcall(vim.fn.getcharstr)
  if ok2 and new_char ~= "" and new_char ~= "\27" then
    change_surround(old, new_char)
  end
end, { desc = "Change Surround" })

vim.keymap.set("n", "ys", function()
  vim.o.operatorfunc = "v:lua.require'mars.core.surround'.opfunc"
  return "g@"
end, { expr = true, desc = "Add Surround" })

vim.keymap.set("n", "yss", function()
  local open_delim, close_delim = prompt_delimiters()
  if not open_delim then
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  wrap_linewise({ row, 0 }, { row, 0 }, open_delim, close_delim)
end, { desc = "Surround Line" })

vim.keymap.set("x", "S", function()
  local visual_mode = vim.fn.mode()
  local start = vim.fn.getpos("v")
  local finish = vim.fn.getpos(".")
  if start[2] > finish[2] or (start[2] == finish[2] and start[3] > finish[3]) then
    start, finish = finish, start
  end

  -- Leave visual mode before prompting; only the selection bounds are needed.
  vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))

  local open_delim, close_delim = prompt_delimiters()
  if not open_delim then
    return
  end

  local start_pos = { start[2], start[3] - 1 }
  local end_pos = { finish[2], finish[3] - 1 }
  if visual_mode == "V" then
    wrap_linewise(start_pos, end_pos, open_delim, close_delim)
  else
    wrap_charwise(start_pos, end_pos, open_delim, close_delim)
  end
end, { desc = "Surround Selection" })

return M
