-- Native bracket/quote auto-pairing (replaces mini.pairs). Four behaviours,
-- each its own small `<expr>` insert-mode
-- keymap per character rather than one InsertCharPre autocmd: expr mappings
-- let a handler simply return the keys to feed (including motions like
-- `<Left>`/`<Right>`), so open/close/skip/backspace each stay a short,
-- independently readable function instead of one big char-dispatch table.
--
-- Scope-down: string/comment suppression uses
-- `vim.treesitter.get_captures_at_pos()` (the same highlight-capture signal
-- `lua/mars/ui/patterns.lua` relies on), gated to buffers where a parser is
-- actually attached; pcall falls through to "not suppressed" for
-- plain-text buffers or filetypes with no parser. Freshness of a pair (for
-- backspace) is not tracked; like mini.pairs' own default, any adjacent
-- matching empty pair is treated as one unit, not just ones this module
-- just inserted.

--- Opening bracket -> matching closer.
local BRACKETS = { ["("] = ")", ["["] = "]", ["{"] = "}" }

--- Closing bracket -> matching opener (for the skip-over/backspace checks).
local CLOSERS = { [")"] = "(", ["]"] = "[", ["}"] = "{" }

--- Quote characters, where opener and closer are the same glyph.
local QUOTES = { ['"'] = true, ["'"] = true, ["`"] = true }

--- Every character (open or close) that matches an empty pair for the
--- backspace-delete-pair check below.
local EMPTY_PAIRS = {}
for open_char, close_char in pairs(BRACKETS) do
  EMPTY_PAIRS[open_char] = close_char
end
for quote in pairs(QUOTES) do
  EMPTY_PAIRS[quote] = quote
end

--- treesitter capture-name prefixes that suppress opening a new pair.
local SUPPRESS_PREFIXES = { "string", "comment" }

--- Character immediately before the cursor, or "" at the start of the
--- line. Byte-indexed: for a multibyte char this returns one byte, not
--- the full character, which is fine here since it's only ever compared
--- against single-byte ASCII bracket/quote characters.
---@return string
local function char_before()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  if col == 0 then
    return ""
  end
  return vim.api.nvim_get_current_line():sub(col, col)
end

--- Character immediately after the cursor, or "" at the end of the line.
--- Same byte-indexing caveat as `char_before`.
---@return string
local function char_after()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(col + 1, col + 1)
end

--- Whether the treesitter node at (0-based) `row, col` is captured as a
--- string or comment. Buffers with no attached parser (the call errors, or
--- returns no captures) are treated as unsuppressed so pairing still works
--- in plain-text files.
---@param row integer 0-based
---@param col integer 0-based
---@return boolean
local function node_is_suppressed(row, col)
  -- Force the parser to sync with pending buffer edits before querying:
  -- the highlighter's cached tree is normally refreshed by the redraw
  -- cycle, which typing fast enough (or a headless/no-UI session) can
  -- outrun, otherwise leaving a just-typed character's context stale.
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
      if capture.capture:sub(1, #prefix) == prefix then
        return true
      end
    end
  end
  return false
end

--- Whether the cursor currently sits inside (or immediately after) a
--- string or comment. Checks both the cursor's column and the one before
--- it: `vim.treesitter` node ranges are half-open (end-exclusive), so
--- appending more text at the very end of an unterminated node, e.g.
--- typing further into a `--` comment that runs to end of line, with no
--- closing delimiter after the cursor, which would otherwise fall just outside
--- the node's range and read as unsuppressed.
---@return boolean
local function in_string_or_comment()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  if node_is_suppressed(row, col) then
    return true
  end
  return col > 0 and node_is_suppressed(row, col - 1)
end

--- Handles typing an opening bracket: inserts the matching closer and
--- places the cursor between them, unless the cursor is inside a
--- string/comment or the next character is a word character (e.g. typing
--- `(` mid-identifier shouldn't split it with a stray pair).
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

--- Handles typing a closing bracket: moves past an already-present
--- matching closer (skip-over) instead of inserting a duplicate. Always
--- available, even inside strings/comments; it never adds a new pair.
---@param close_char string
---@return string
local function close_bracket(close_char)
  if char_after() == close_char then
    return "<Right>"
  end
  return close_char
end

--- Handles typing a quote character (opener and closer are the same
--- glyph): skips over an immediately-following matching quote; otherwise
--- opens a new pair unless the cursor is inside a string/comment, or is
--- adjacent to a word character, guarding contractions like "don't" and
--- mid-identifier quotes from being paired.
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

--- Handles `<BS>`: deletes both characters of an adjacent empty pair (e.g.
--- `(|)`, `"|"`) as one unit instead of leaving a dangling closer behind.
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
