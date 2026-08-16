-- Native jump-to-label: type two characters, labels appear over every
-- visible match, press one to jump. A reduced-scope stand-in for
-- flash.nvim's `s`/`S`: fixing the search at
-- exactly two characters sidesteps flash's label-reuse and
-- label-collision machinery; only the current window is searched, and `S`
-- is an alias (no treesitter mode here).

local M = {}

--- Label alphabet in priority order: closest matches get the easiest keys.
local ALPHABET = "asdfghjklqwertyuiopzxcvbnm"

local NAMESPACE = vim.api.nvim_create_namespace("mars_jump")
local HIGHLIGHT = "MarsJumpLabel"

vim.api.nvim_set_hl(0, HIGHLIGHT, { link = "IncSearch", default = true })

---@class MarsJump.Match
---@field lnum integer 1-indexed line number
---@field col integer 0-indexed byte column where the match starts
---@field label string? single-character label assigned to this match

--- Reads one character; nil on `<Esc>`/`<C-c>` so callers treat those as
--- "cancel".
---@return string?
local function get_char()
  local ok, char = pcall(vim.fn.getcharstr)
  if not ok or char == "\27" or char == "\3" then
    return nil
  end
  return char
end

--- Literal (non-regex) occurrences of `pattern` in the window's visible
--- lines, honouring 'ignorecase'/'smartcase' like `/`.
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

--- Sorts `matches` by absolute on-screen distance from `cursor`, so closer
--- matches get easier-to-reach labels.
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

--- Assigns each match a single-character label in `ALPHABET` order; matches
--- beyond the alphabet's length stay unlabeled.
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
--- text's first cell with the label.
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

--- Moves to `match`, entering charwise visual mode first for operator
--- mappings so the operator range is inclusive of the target character.
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

--- Bound to `s`/`S`: reads a fixed two-character search string, labels
--- every visible match, then jumps to the label keyed. Cancels on
--- `<Esc>`/`<C-c>` or an unmatched label.
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
  -- Forced redraw: the overlay extmarks replaced real cells, and some
  -- terminals don't repaint every affected cell on a plain `redraw` once
  -- they're gone, leaving stale label glyphs ("ghost" characters).
  vim.cmd("redraw!")

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

-- `S` isn't bound: it would only duplicate `s` (no treesitter mode to
-- distinguish), and visual-mode `S` is wanted for surround-style bindings.
vim.keymap.set({ "n", "x", "o" }, "s", M.jump, { desc = "Jump to a 2-char label" })

return M
