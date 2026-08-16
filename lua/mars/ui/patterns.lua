-- Native pattern highlighting: comment keywords (TODO/FIXME/HACK/NOTE/WARN/
-- PERF) and hex colour literals shown in their own colour. Autocmd-driven
-- ('matchadd' is window-local and doesn't survive window changes), scoped
-- to the visible line range, debounced.

local M = {}

local ns = vim.api.nvim_create_namespace("mars_patterns")

-- Buffers larger than this are skipped entirely rather than scanned.
local max_bytes = 1024 * 1024

local debounce = require("mars.helpers.debounce")
local color = require("mars.helpers.color")

local keyword_groups = {
  TODO = "Todo",
  FIXME = "DiagnosticError",
  HACK = "DiagnosticWarn",
  WARN = "DiagnosticWarn",
  NOTE = "DiagnosticInfo",
  PERF = "DiagnosticHint",
}

-- Per-colour highlight groups can't be predeclared, so one is created
-- dynamically per distinct hex value and cached.
local hex_group_cache = {} ---@type table<string, string>

--- Expands a 3-digit hex colour to its 6-digit form; leaves 6-digit input
--- unchanged.
---@param hex string 3 or 6 hex digits, no leading '#'
---@return string
local function normalize_hex(hex)
  if #hex == 3 then
    local r, g, b = hex:sub(1, 1), hex:sub(2, 2), hex:sub(3, 3)
    return r .. r .. g .. g .. b .. b
  end
  return hex
end

--- Returns the highlight group for a hex colour background, creating it the
--- first time this colour is seen.
---@param hex string 6-digit hex colour, lowercase, no leading '#'
---@return string
local function hex_highlight_group(hex)
  local existing = hex_group_cache[hex]
  if existing then
    return existing
  end
  local name = "MarsPatternsColor" .. hex
  vim.api.nvim_set_hl(0, name, { bg = "#" .. hex, fg = color.readable_fg(hex) })
  hex_group_cache[hex] = name
  return name
end

--- Finds hex colour literals (#rgb or #rrggbb) in a line, rejecting matches
--- that are part of a longer run of word/hex characters.
---@param line string
---@return { start_col: integer, end_col: integer, hex: string }[]
local function find_hex_colors(line)
  local matches = {}
  local init = 1
  while true do
    local s = line:find("#", init, true)
    if not s then
      break
    end
    local rest = line:sub(s + 1)
    local hex = rest:match("^(%x%x%x%x%x%x)") or rest:match("^(%x%x%x)")
    if hex then
      local e = s + #hex
      local before = line:sub(s - 1, s - 1)
      local after = line:sub(e + 1, e + 1)
      if not before:match("[%w#]") and not after:match("%w") then
        matches[#matches + 1] = { start_col = s - 1, end_col = e, hex = normalize_hex(hex:lower()) }
      end
      init = e + 1
    else
      init = s + 1
    end
  end
  return matches
end

--- Whether the treesitter node at a buffer position is a comment (or nested
--- inside one). Returns false if the buffer has no attached parser.
---@param bufnr integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
local function in_comment(bufnr, row, col)
  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok_parser or not parser then
    return false
  end
  local ok_node, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
  if not ok_node or not node then
    return false
  end
  local current = node
  while current do
    if current:type():find("comment", 1, true) then
      return true
    end
    current = current:parent()
  end
  return false
end

--- Finds comment keywords in a line, rejecting matches that are part of a
--- longer word.
---@param line string
---@return { start_col: integer, end_col: integer, group: string }[]
local function find_keywords(line)
  local matches = {}
  for word, group in pairs(keyword_groups) do
    local init = 1
    while true do
      local s, e = line:find(word, init, true)
      if not s then
        break
      end
      local before = line:sub(s - 1, s - 1)
      local after = line:sub(e + 1, e + 1)
      if not before:match("[%w_]") and not after:match("[%w_]") then
        matches[#matches + 1] = { start_col = s - 1, end_col = e, group = group }
      end
      init = e + 1
    end
  end
  return matches
end

--- Scans a single line and sets its extmarks. Keyword matches are dropped
--- unless they fall inside a comment node.
---@param bufnr integer
---@param row integer 0-indexed
---@param line string
local function scan_line(bufnr, row, line)
  for _, match in ipairs(find_hex_colors(line)) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, match.start_col, {
      end_col = match.end_col,
      hl_group = hex_highlight_group(match.hex),
    })
  end

  for _, match in ipairs(find_keywords(line)) do
    if in_comment(bufnr, row, match.start_col) then
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, match.start_col, {
        end_col = match.end_col,
        hl_group = match.group,
      })
    end
  end
end

--- Rescans the given [first, last) 0-indexed line range, replacing any
--- extmarks previously set there.
---@param bufnr integer
---@param first integer
---@param last integer
local function scan_range(bufnr, first, last)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, first, last)
  local lines = vim.api.nvim_buf_get_lines(bufnr, first, last, false)
  for i, line in ipairs(lines) do
    scan_line(bufnr, first + i - 1, line)
  end
end

--- Total byte size of a buffer's content, or -1 if it can't be determined
--- (e.g. the buffer isn't loaded).
---@param bufnr integer
---@return integer
local function buffer_size(bufnr)
  local ok, offset = pcall(vim.api.nvim_buf_get_offset, bufnr, vim.api.nvim_buf_line_count(bufnr))
  if not ok then
    return -1
  end
  return offset
end

--- Whether a buffer is worth scanning at all: a plain on-disk-style buffer
--- (empty 'buftype', excludes help/quickfix/terminal/prompt/netrw) under
--- the size cap.
---@param bufnr integer
---@return boolean
local function is_eligible(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  local size = buffer_size(bufnr)
  return size >= 0 and size <= max_bytes
end

--- Rescans a buffer's visible region (or the whole buffer, if it isn't
--- shown in any window). Ineligible buffers are cleared instead; a
--- since-deleted buffer is silently skipped.
---@param bufnr? integer defaults to the current buffer
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not is_eligible(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    return
  end
  local winid = vim.fn.bufwinid(bufnr)
  local first, last
  if winid ~= -1 then
    first, last = vim.fn.line("w0", winid) - 1, vim.fn.line("w$", winid)
  else
    first, last = 0, vim.api.nvim_buf_line_count(bufnr)
  end
  scan_range(bufnr, first, last)
end

local group = vim.api.nvim_create_augroup("mars_patterns", { clear = true })

vim.api.nvim_create_autocmd(
  { "BufReadPost", "BufNewFile", "BufEnter", "WinScrolled", "TextChanged", "TextChangedI", "InsertLeave" },
  {
    group = group,
    desc = "Rescan visible pattern highlights for the current buffer",
    callback = function(ev)
      debounce.debounced(ev.buf, function()
        M.refresh(ev.buf)
      end)
    end,
  }
)

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  desc = "Drop debounce bookkeeping for a deleted or wiped-out buffer",
  callback = function(ev)
    debounce.drop(ev.buf)
  end,
})

return M
