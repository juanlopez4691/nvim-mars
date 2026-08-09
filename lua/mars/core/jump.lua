-- Minimal native jump-to-label motion: type exactly two characters, and a
-- single-character label appears over every visible match on screen; press
-- that label to jump the cursor there instantly.
--
-- This is a deliberately reduced-scope native stand-in for flash.nvim's
-- core `s`/`S` flow (see AGENTS.md's Native-First
-- Philosophy for the judgment call this file makes). Left out on purpose,
-- because covering them well needs real algorithmic machinery this file
-- doesn't have:
--   * Live incremental search-as-you-type with reusable/stable labels
--     across keystrokes (flash's `label.reuse`).
--   * Ambiguous-label avoidance while the pattern is still growing (flash's
--     `Labeler:skip`; buffer-wide regex scans to keep a label key from
--     colliding with a valid pattern continuation). This module sidesteps
--     the whole problem by fixing the search at exactly two characters
--     before any label is ever shown, so "still typing the pattern" and
--     "picking a label" never overlap.
--   * Multi-window jumping (only the current window's visible lines are
--     searched).
--   * Treesitter node selection (`S` in flash defaults to this; here it's
--     just an alias for the same two-char jump, since there's no
--     treesitter mode to bind it to).

local M = {}

--- Label alphabet in priority order: closest matches get the
--- easiest-to-reach keys first. Mirrors flash.nvim's default ordering
--- (home row first).
local ALPHABET = "asdfghjklqwertyuiopzxcvbnm"

local NAMESPACE = vim.api.nvim_create_namespace("mars_jump")
local HIGHLIGHT = "MarsJumpLabel"

vim.api.nvim_set_hl(0, HIGHLIGHT, { link = "IncSearch", default = true })

---@class MarsJump.Match
---@field lnum integer 1-indexed line number
---@field col integer 0-indexed byte column where the match starts
---@field label string? single-character label assigned to this match

--- Reads one character from the user. Returns `nil` on `<Esc>`/`<C-c>` so
--- callers can treat those uniformly as "cancel".
---@return string?
local function get_char()
  local ok, char = pcall(vim.fn.getcharstr)
  if not ok or char == "\27" or char == "\3" then
    return nil
  end
  return char
end

--- Finds every occurrence of the literal (non-regex) `pattern` inside the
--- given window's currently visible lines, honouring 'ignorecase'/
--- 'smartcase' the same way a native `/` search would.
---@param win integer
---@param pattern string
---@return MarsJump.Match[]
local function find_matches(win, pattern)
  local buf = vim.api.nvim_win_get_buf(win)
  local top = vim.fn.line("w0", win)
  local bottom = vim.fn.line("w$", win)
  local lines = vim.api.nvim_buf_get_lines(buf, top - 1, bottom, false)

  local fold_case = vim.o.ignorecase and not (vim.o.smartcase and pattern:match("%u"))
  local needle = fold_case and pattern:lower() or pattern

  ---@type MarsJump.Match[]
  local matches = {}
  for i, line in ipairs(lines) do
    local hay = fold_case and line:lower() or line
    local from = 1
    while true do
      local s = hay:find(needle, from, true)
      if not s then
        break
      end
      matches[#matches + 1] = { lnum = top + i - 1, col = s - 1 }
      from = s + 1
    end
  end
  return matches
end

--- Sorts `matches` in place by absolute on-screen distance from `cursor`
--- (1-indexed line, 0-indexed col), so closer matches get shorter/
--- easier-to-reach labels, mirroring flash.nvim's default `label.distance`.
---@param matches MarsJump.Match[]
---@param cursor integer[]
local function sort_by_distance(matches, cursor)
  local width = math.max(vim.o.columns, 1)
  local from = cursor[1] * width + cursor[2]
  table.sort(matches, function(a, b)
    local da = math.abs((a.lnum * width + a.col) - from)
    local db = math.abs((b.lnum * width + b.col) - from)
    return da < db
  end)
end

--- Assigns a single-character label (in `ALPHABET` order) to each match, up
--- to the alphabet's length. Matches beyond that are left unlabeled, the same
--- fallback flash.nvim uses when a screen has more matches than available
--- label characters.
---@param matches MarsJump.Match[]
local function assign_labels(matches)
  for i, match in ipairs(matches) do
    if i > #ALPHABET then
      break
    end
    match.label = ALPHABET:sub(i, i)
  end
end

--- Renders one overlay extmark per labeled match, replacing the matched
--- text's first cell with the label character.
---@param buf integer
---@param matches MarsJump.Match[]
local function render(buf, matches)
  for _, match in ipairs(matches) do
    if match.label then
      vim.api.nvim_buf_set_extmark(buf, NAMESPACE, match.lnum - 1, match.col, {
        virt_text = { { match.label, HIGHLIGHT } },
        virt_text_pos = "overlay",
        priority = 200,
        hl_mode = "combine",
      })
    end
  end
end

--- Clears any labels drawn by `render`.
---@param buf integer
local function clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, NAMESPACE, 0, -1)
end

--- Moves the cursor to `match`, handling the jumplist and operator-pending
--- inclusivity the same way flash.nvim does: entering charwise visual mode
--- before repositioning the cursor makes the resulting operator range
--- inclusive of the target character, instead of the exclusive default a
--- plain cursor move would give an operator-pending mapping.
---@param win integer
---@param match MarsJump.Match
---@param is_op boolean
local function jump_to(win, match, is_op)
  vim.cmd("normal! m'")
  if is_op then
    vim.cmd("normal! v")
  end
  vim.api.nvim_win_set_cursor(win, { match.lnum, match.col })
end

--- Entry point bound to `s`/`S` below: reads a fixed two-character search
--- string, labels every visible match on screen, then reads one more
--- character and jumps to whichever match owns that label. Cancels
--- cleanly on `<Esc>`/`<C-c>` at any point, or if the pressed label
--- doesn't match any rendered one.
function M.jump()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local is_op = vim.fn.mode(true):sub(1, 2) == "no"

  local c1 = get_char()
  if not c1 then
    return
  end
  local c2 = get_char()
  if not c2 then
    return
  end
  local pattern = c1 .. c2

  local matches = find_matches(win, pattern)
  if #matches == 0 then
    return
  end

  sort_by_distance(matches, vim.api.nvim_win_get_cursor(win))
  assign_labels(matches)
  render(buf, matches)
  vim.cmd("redraw")

  local label = get_char()
  clear(buf)
  vim.cmd("redraw")

  if not label then
    return
  end

  for _, match in ipairs(matches) do
    if match.label == label then
      jump_to(win, match, is_op)
      return
    end
  end
end

vim.keymap.set({ "n", "x", "o" }, "s", M.jump, { desc = "Jump to a 2-char label" })
vim.keymap.set({ "n", "x", "o" }, "S", M.jump, { desc = "Jump to a 2-char label" })

return M
