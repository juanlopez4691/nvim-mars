-- Native bracket/quote auto-pairing (replaces mini.pairs). One `<expr>`
-- insert-mode keymap per character, each a small
-- function. Pairing is suppressed inside strings/comments via treesitter
-- highlight captures; pair freshness isn't tracked, so any adjacent
-- matching empty pair is treated as one unit (mini.pairs' own default).

--- Opening bracket -> matching closer.
local BRACKETS = { ["("] = ")", ["["] = "]", ["{"] = "}" }

--- Closing bracket -> matching opener (for the skip-over/backspace checks).
local CLOSERS = { [")"] = "(", ["]"] = "[", ["}"] = "{" }

--- Quote characters, where opener and closer are the same glyph.
local QUOTES = { ['"'] = true, ["'"] = true, ["`"] = true }

--- Every character that can form an empty pair, for backspace-delete-pair.
local EMPTY_PAIRS = {}
for open_char, close_char in pairs(BRACKETS) do
  EMPTY_PAIRS[open_char] = close_char
end
for quote in pairs(QUOTES) do
  EMPTY_PAIRS[quote] = quote
end

--- treesitter capture-name prefixes that suppress opening a new pair.
local SUPPRESS_PREFIXES = { "string", "comment" }

--- Character before the cursor, or "" at the start of the line. Byte-
--- indexed; fine, since it's only ever compared against single-byte
--- ASCII brackets/quotes.
---@return string
local function char_before()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  if col == 0 then
    return ""
  end
  return vim.api.nvim_get_current_line():sub(col, col)
end

--- Character after the cursor, or "" at the end of the line. Same
--- byte-indexing caveat as `char_before`.
---@return string
local function char_after()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(col + 1, col + 1)
end

--- Whether the treesitter node at (0-based) `row, col` is a string or
--- comment. Buffers with no parser fall through as unsuppressed.
---@param row integer 0-based
---@param col integer 0-based
---@return boolean
local function node_is_suppressed(row, col)
  -- Force the parser to sync with pending edits: the highlighter's cached
  -- tree can otherwise lag behind a just-typed character.
  local ok_parser, parser = pcall(vim.treesitter.get_parser, 0)
  if ok_parser and parser then
    pcall(parser.parse, parser)
  end

  local ok, captures = pcall(vim.treesitter.get_captures_at_pos, 0, row, col)
  if not ok then
    return false
  end
  for _, capture in ipairs(captures) do
    for _, prefix in ipairs(SUPPRESS_PREFIXES) do
      if vim.startswith(capture.capture, prefix) then
        return true
      end
    end
  end
  return false
end

--- Whether the cursor sits inside (or just after) a string/comment. The
--- column before the cursor is checked too because node ranges are
--- half-open: appending at the very end of an unterminated node (e.g. a
--- `--` comment running to EOL) would otherwise read as unsuppressed.
---@return boolean
local function in_string_or_comment()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  if node_is_suppressed(row, col) then
    return true
  end
  return col > 0 and node_is_suppressed(row, col - 1)
end

--- Handles an opening bracket: inserts closer and places the cursor
--- between them, unless inside a string/comment or before a word char
--- (typing `(` mid-identifier shouldn't split it).
---@param open_char string
---@param close_char string
---@return string
local function open_bracket(open_char, close_char)
  if in_string_or_comment() then
    return open_char
  end

  local after = char_after()
  if after ~= "" and after:match("%w") then
    return open_char
  end

  return open_char .. close_char .. "<Left>"
end

--- Handles a closing bracket: moves past an already-present matching
--- closer instead of duplicating it. Always active, even in strings/
--- comments; it never adds a pair.
---@param close_char string
---@return string
local function close_bracket(close_char)
  if char_after() == close_char then
    return "<Right>"
  end
  return close_char
end

--- Handles a quote: skips an immediately-following matching quote,
--- otherwise opens a pair unless inside a string/comment or adjacent to a
--- word char (guards contractions like "don't").
---@param quote string
---@return string
local function pair_quote(quote)
  if char_after() == quote then
    return "<Right>"
  end

  if in_string_or_comment() then
    return quote
  end

  local before, after = char_before(), char_after()
  if (before ~= "" and before:match("%w")) or (after ~= "" and after:match("%w")) then
    return quote
  end

  return quote .. quote .. "<Left>"
end

--- Handles `<BS>`: deletes both chars of an adjacent empty pair (e.g.
--- `(|)`, `"|"`) as one unit.
---@return string
local function backspace()
  local before, after = char_before(), char_after()
  if before ~= "" and EMPTY_PAIRS[before] == after then
    return "<BS><Del>"
  end
  return "<BS>"
end

for open_char, close_char in pairs(BRACKETS) do
  vim.keymap.set("i", open_char, function()
    return open_bracket(open_char, close_char)
  end, { expr = true, desc = ("Pairs: auto-close %s"):format(open_char) })
end

for close_char in pairs(CLOSERS) do
  vim.keymap.set("i", close_char, function()
    return close_bracket(close_char)
  end, { expr = true, desc = ("Pairs: skip over %s"):format(close_char) })
end

for quote in pairs(QUOTES) do
  vim.keymap.set("i", quote, function()
    return pair_quote(quote)
  end, { expr = true, desc = ("Pairs: auto-close/skip %s"):format(quote) })
end

vim.keymap.set("i", "<BS>", backspace, { expr = true, desc = "Pairs: delete an empty pair as a unit" })
