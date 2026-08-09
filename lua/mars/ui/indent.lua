-- Native indent guides: a vertical guide character at each indentation
-- level for the visible window range, plus a distinct highlight for the
-- guide marking the cursor's current Treesitter scope. Rendered with
-- overlay extmarks (`virt_text_win_col`) the same way
-- `lua/mars/ui/patterns.lua` uses extmarks, scoped to the visible line
-- range, and debounced so bursts of edits/movement collapse into a single
-- redraw. Skips floats/terminals/quickfix/etc. the same way
-- `lua/mars/core/lines.lua` detects special buffers.

local M = {}

local ns = vim.api.nvim_create_namespace("mars_indent")
local group = vim.api.nvim_create_augroup("mars_indent", { clear = true })

-- Buffers larger than this are skipped entirely rather than scanned.
local max_bytes = 1024 * 1024
local debounce_ms = 100

-- Off-screen lines of context fetched around the visible range so a blank
-- line at its edge can still infer its guide depth from the nearest
-- non-blank neighbour, without scanning the whole buffer.
local context_pad = 50

-- Hard cap on guide columns drawn per line; guards against a pathological
-- line (e.g. in a minified file) producing an unbounded number of
-- extmarks.
local max_levels = 64

--- Buftypes that mark a window as plugin UI / special-purpose, never worth
--- drawing guides in. Mirrors `lua/mars/core/lines.lua`.
local UI_BUFTYPES = {
  help = true,
  nofile = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

--- Pending debounce generation per window; a redraw only runs if its
--- generation is still the latest requested for that window.
local pending = {} ---@type table<integer, integer>

--- (Re)defines Mars's indent-guide highlight groups: a dim colour for
--- ordinary guides, and a brighter one for the guide marking the cursor's
--- current Treesitter scope. Reapplied on `ColorScheme` since built-in
--- colorschemes clear all highlight groups when they load (same pattern as
--- `lua/mars/ui/colorscheme.lua`).
local function apply_highlights()
  vim.api.nvim_set_hl(0, "MarsIndentGuide", { link = "Comment" })
  vim.api.nvim_set_hl(0, "MarsIndentGuideScope", { link = "CursorLineNr" })
end

--- Effective 'shiftwidth' for `bufnr`, resolving the shiftwidth=0 ("use
--- 'tabstop' instead") case the same way Vim itself does.
---@param bufnr integer
---@return integer
local function effective_shiftwidth(bufnr)
  return vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.shiftwidth()
  end)
end

--- Indentation level of a single line: its leading whitespace's display
--- width divided by `shiftwidth`, rounded down. Blank (or whitespace-only)
--- lines return nil; callers resolve their level from surrounding context
--- instead, see `resolve_levels`.
---@param line string
---@param shiftwidth integer
---@return integer?
local function line_level(line, shiftwidth)
  if line:match("^%s*$") then
    return nil
  end
  local leading = line:match("^%s*")
  return math.floor(vim.fn.strdisplaywidth(leading) / shiftwidth)
end

--- Indent level for every line in `[first, last)` (0-indexed, exclusive).
--- A blank line takes the smaller of its nearest non-blank neighbours'
--- levels, so a blank line inside a block still shows guides through it,
--- but never deeper than either side actually reaches, falling back to
--- a level of 0 if no non-blank neighbour is found within `context_pad`
--- lines.
---@param bufnr integer
---@param first integer
---@param last integer
---@param shiftwidth integer
---@return integer[] levels indexed 1..(last-first)
local function resolve_levels(bufnr, first, last, shiftwidth)
  local pad_first = math.max(0, first - context_pad)
  local pad_last = math.min(vim.api.nvim_buf_line_count(bufnr), last + context_pad)
  local lines = vim.api.nvim_buf_get_lines(bufnr, pad_first, pad_last, false)

  local raw = {} ---@type (integer?)[]
  for i, line in ipairs(lines) do
    raw[i] = line_level(line, shiftwidth)
  end

  local levels = {} ---@type integer[]
  for row = first, last - 1 do
    local i = row - pad_first + 1
    local level = raw[i]
    if not level then
      local prev
      for j = i - 1, 1, -1 do
        if raw[j] then
          prev = raw[j]
          break
        end
      end
      local next_level
      for j = i + 1, #raw do
        if raw[j] then
          next_level = raw[j]
          break
        end
      end
      level = (prev and next_level) and math.min(prev, next_level) or 0
    end
    levels[row - first + 1] = level
  end
  return levels
end

--- The current cursor's enclosing Treesitter scope: the nearest ancestor
--- of the node at `(row, col)` (including that node itself) whose range
--- spans more than one line. A generic, language-agnostic stand-in for a
--- "scope": no per-language query, just the first multi-line container.
--- Returns nil if the buffer has no attached parser, or no node at the
--- position spans multiple lines (e.g. an empty buffer).
---@param bufnr integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return integer? start_row, integer? end_row 0-indexed, inclusive
local function current_scope(bufnr, row, col)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok_parser or not parser then
    return nil
  end
  local ok_node, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
  if not ok_node or not node then
    return nil
  end
  local current = node
  while current do
    local srow, _, erow, ecol = current:range()
    -- A node ending at column 0 of `erow` doesn't actually reach into that
    -- row's text (common for blocks whose closing token is followed by a
    -- newline captured in the range); treat its last real row as erow-1.
    if ecol == 0 then
      erow = erow - 1
    end
    if erow > srow then
      return srow, erow
    end
    current = current:parent()
  end
  return nil
end

--- Screen column of the guide that marks scope `[srow, erow]`'s body: the
--- indent level of the first non-blank line inside the scope, or, if the
--- whole body is blank, one level deeper than the opening line itself.
---@param bufnr integer
---@param srow integer 0-indexed
---@param erow integer 0-indexed, inclusive
---@param shiftwidth integer
---@return integer col 0-indexed screen column
local function scope_column(bufnr, srow, erow, shiftwidth)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local probe_end = math.min(erow, line_count - 1)
  for row = math.min(srow + 1, probe_end), probe_end do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    local level = line_level(line, shiftwidth)
    if level then
      return (level - 1) * shiftwidth
    end
  end
  local open_line = vim.api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)[1] or ""
  local open_level = line_level(open_line, shiftwidth) or 0
  return open_level * shiftwidth
end

--- Whether `bufnr`/`winid` is worth drawing guides in: a plain,
--- non-floating window (mirrors `lua/mars/core/lines.lua`'s
--- `is_normal_window`) over a buffer under the size cap.
---@param bufnr integer
---@param winid integer
---@return boolean
local function is_eligible(bufnr, winid)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  if UI_BUFTYPES[vim.bo[bufnr].buftype] then
    return false
  end
  local ok_config, win_config = pcall(vim.api.nvim_win_get_config, winid)
  if not ok_config or win_config.relative ~= "" then
    return false
  end
  local ok_offset, size = pcall(vim.api.nvim_buf_get_offset, bufnr, vim.api.nvim_buf_line_count(bufnr))
  return ok_offset and size >= 0 and size <= max_bytes
end

--- Rescans and redraws indent guides for the buffer shown in `winid`,
--- including the current-scope highlight for that window's cursor
--- position. Ineligible windows (see `is_eligible`) have their buffer's
--- guides cleared instead.
---@param winid? integer defaults to the current window
function M.refresh(winid)
  winid = winid or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(winid)

  if not is_eligible(bufnr, winid) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    return
  end

  local first = vim.fn.line("w0", winid) - 1
  local last = vim.fn.line("w$", winid)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, first, last)

  local shiftwidth = effective_shiftwidth(bufnr)
  if shiftwidth <= 0 then
    return
  end

  local levels = resolve_levels(bufnr, first, last, shiftwidth)

  local scope_col, scope_start, scope_end
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local srow, erow = current_scope(bufnr, cursor[1] - 1, cursor[2])
  if srow then
    scope_start, scope_end = srow, erow
    scope_col = scope_column(bufnr, srow, erow, shiftwidth)
  end

  -- Read the Nerd Font flag here, at draw time, rather than memoizing it;
  -- `lua/mars/local.lua` (where users actually set it) loads after every
  -- ui/ module, so an upvalue would freeze to the plain-text fallback.
  local guide_char = vim.g.have_nerd_font and "│" or "|"

  for row = first, last - 1 do
    local level = math.min(levels[row - first + 1] or 0, max_levels)
    for l = 1, level do
      local col = (l - 1) * shiftwidth
      local hl = "MarsIndentGuide"
      if scope_col and col == scope_col and row >= scope_start and row <= scope_end then
        hl = "MarsIndentGuideScope"
      end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
        virt_text = { { guide_char, hl } },
        virt_text_win_col = col,
      })
    end
  end
end

--- Debounces a redraw for a window: bursts of events within `debounce_ms`
--- collapse into a single scan of the last-requested state.
---@param winid integer
local function schedule_refresh(winid)
  local generation = (pending[winid] or 0) + 1
  pending[winid] = generation
  vim.defer_fn(function()
    if pending[winid] == generation then
      M.refresh(winid)
    end
  end, debounce_ms)
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  desc = "Reapply Mars indent-guide highlight groups after the colorscheme (re)loads",
  callback = apply_highlights,
})

vim.api.nvim_create_autocmd({
  "BufReadPost",
  "BufNewFile",
  "BufEnter",
  "WinEnter",
  "WinScrolled",
  "TextChanged",
  "TextChangedI",
  "InsertLeave",
  "CursorMoved",
  "CursorMovedI",
}, {
  group = group,
  desc = "Rescan indent guides and cursor scope for the current window",
  callback = function()
    schedule_refresh(vim.api.nvim_get_current_win())
  end,
})

vim.api.nvim_create_autocmd("WinClosed", {
  group = group,
  desc = "Drop debounce bookkeeping for a closed window",
  callback = function(ev)
    pending[tonumber(ev.match)] = nil
  end,
})

apply_highlights()

return M
