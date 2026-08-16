-- Native vim.notify replacement: each message floats in a small window
-- stacked top-right, auto-dismissed after a level-dependent timeout.

-- Substrings that mark a message as noise rather than signal: still written
-- to :messages via the original vim.notify, just never floated. Add by
-- exact substring, not a regex.
local suppressed_patterns = {
  "No information available",
  -- blade-nav registering an nvim-cmp source: expected; Mars has no nvim-cmp.
  "BladeNav Warn",
}

local levels = vim.log.levels

local text = require("mars.helpers.text")

local hl_by_level = {
  [levels.ERROR] = "DiagnosticError",
  [levels.WARN] = "DiagnosticWarn",
  [levels.INFO] = "DiagnosticInfo",
  [levels.DEBUG] = "DiagnosticHint",
  [levels.TRACE] = "DiagnosticHint",
}

-- Plain letters are the always-safe default; vim.g.have_nerd_font is set in
-- lua/mars/local.lua, which loads after this module, so read it at render
-- time rather than memoizing here.
local nerd_font_icon_by_level = {
  [levels.ERROR] = "󰅚 ",
  [levels.WARN] = "󰀪 ",
  [levels.INFO] = "󰋽 ",
  [levels.DEBUG] = "󰌶 ",
  [levels.TRACE] = "󰌶 ",
}
local plain_icon_by_level = {
  [levels.ERROR] = "E ",
  [levels.WARN] = "W ",
  [levels.INFO] = "I ",
  [levels.DEBUG] = "D ",
  [levels.TRACE] = "T ",
}

--- Icon for a given notify level, gated behind vim.g.have_nerd_font.
---@param level integer
---@return string
local function icon_for(level)
  local icons = vim.g.have_nerd_font and nerd_font_icon_by_level or plain_icon_by_level
  return icons[level] or ""
end

-- Auto-dismiss timeout per level, in milliseconds.
local timeout_by_level = {
  [levels.ERROR] = 8000,
  [levels.WARN] = 6000,
  [levels.INFO] = 4000,
  [levels.DEBUG] = 4000,
  [levels.TRACE] = 4000,
}

local MARGIN = 1
local GAP = 1
local MAX_WIDTH = 60

-- Content padding, added around the message inside the border: one column
-- of blank space left/right, one blank line above/below.
local PAD_X = 1
local PAD_Y = 1

-- Must match the module path require_dir() derives for this file, so a
-- manual :source of this buffer finds what an earlier load stashed here.
local MODULE_NAME = "mars.ui.notify"

-- The un-overridden vim.notify, kept as the :messages sink and the fallback
-- for internal failures. Stashed in package.loaded so a re-source resolves
-- it back instead of wrapping this wrapper.
local stashed = package.loaded[MODULE_NAME]
local default_notify = (type(stashed) == "table" and stashed.default_notify) or vim.notify

---@class MarsNotifyEntry
---@field win integer
---@field buf integer
---@field height integer Screen rows occupied, border included.
---@field timer uv.uv_timer_t?

--- Floats currently on screen, ordered top to bottom.
---@type MarsNotifyEntry[]
local active = {}

--- Whether msg contains any of suppressed_patterns as a plain substring.
---@param msg string
---@return boolean
local function is_suppressed(msg)
  for _, pattern in ipairs(suppressed_patterns) do
    if msg:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

--- Greedily wraps text to at most `width` display columns, splitting on
--- whitespace; a single word longer than `width` is hard-truncated.
---@param msg string
---@param width integer
---@return string[]
local function wrap_lines(msg, width)
  width = math.max(1, width)
  local lines = {}
  for _, raw_line in ipairs(vim.split(msg, "\n", { plain = true })) do
    local line = ""
    for word in raw_line:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if vim.fn.strdisplaywidth(candidate) > width then
        if line ~= "" then
          lines[#lines + 1] = line
        end
        line = vim.fn.strdisplaywidth(word) > width and text.truncate_to_width(word, width) or word
      else
        line = candidate
      end
    end
    lines[#lines + 1] = line
  end
  return lines
end

--- Repositions every remaining float so they stack, right-aligned, without
--- gaps or overlaps. Safe to call after any float is added or removed.
local function reflow()
  local row = MARGIN
  for _, entry in ipairs(active) do
    if vim.api.nvim_win_is_valid(entry.win) then
      vim.api.nvim_win_set_config(entry.win, {
        relative = "editor",
        anchor = "NE",
        row = row,
        col = vim.o.columns - MARGIN,
      })
      row = row + entry.height + GAP
    end
  end
end

--- Tears down one float's timer, window and buffer, then reflows the rest.
--- Safe to call more than once for the same entry.
---@param entry MarsNotifyEntry
local function dismiss(entry)
  if entry.timer then
    pcall(function()
      entry.timer:stop()
      entry.timer:close()
    end)
    entry.timer = nil
  end

  for i, e in ipairs(active) do
    if e == entry then
      table.remove(active, i)
      break
    end
  end

  if vim.api.nvim_win_is_valid(entry.win) then
    vim.api.nvim_win_close(entry.win, true)
  end
  if vim.api.nvim_buf_is_valid(entry.buf) then
    vim.api.nvim_buf_delete(entry.buf, { force = true })
  end

  reflow()
end

--- Builds and shows the float for one message. Must run on the main loop
--- (call sites schedule it); never call directly from a fast-event context.
---@param msg string
---@param level integer
local function render(msg, level)
  local icon = icon_for(level)
  local hl = hl_by_level[level] or "DiagnosticInfo"
  local indent = string.rep(" ", vim.fn.strdisplaywidth(icon))

  local available = math.max(20, vim.o.columns - (MARGIN * 2) - 2)
  local width = math.min(MAX_WIDTH, available)
  -- Reserve PAD_X columns on each side for the horizontal padding below.
  local text_width = math.max(1, width - vim.fn.strdisplaywidth(icon) - (PAD_X * 2))

  local lines = {}
  for i, body_line in ipairs(wrap_lines(msg, text_width)) do
    lines[i] = (i == 1 and icon or indent) .. body_line
  end
  if #lines == 0 then
    lines = { icon }
  end

  local content_width = 1
  for _, line in ipairs(lines) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
  end
  content_width = math.min(width - (PAD_X * 2), content_width)
  local win_width = content_width + (PAD_X * 2)

  local left_pad = string.rep(" ", PAD_X)
  local padded_lines = {}
  for _ = 1, PAD_Y do
    padded_lines[#padded_lines + 1] = ""
  end
  for _, line in ipairs(lines) do
    padded_lines[#padded_lines + 1] = left_pad .. line .. left_pad
  end
  for _ = 1, PAD_Y do
    padded_lines[#padded_lines + 1] = ""
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, padded_lines)

  local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
    relative = "editor",
    anchor = "NE",
    row = MARGIN,
    col = vim.o.columns - MARGIN,
    width = win_width,
    height = #padded_lines,
    style = "minimal",
    border = require("mars.ui.borders").style(),
    focusable = false,
    noautocmd = true,
    zindex = 200,
  })
  if not ok or not win then
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    return
  end

  vim.wo[win].winhighlight = ("Normal:NormalFloat,FloatBorder:%s"):format(hl)

  ---@type MarsNotifyEntry
  local entry = { win = win, buf = buf, height = #padded_lines + 2, timer = nil }
  active[#active + 1] = entry

  local timer = vim.uv.new_timer()
  if timer then
    entry.timer = timer
    timer:start(
      timeout_by_level[level] or timeout_by_level[levels.INFO],
      0,
      vim.schedule_wrap(function()
        dismiss(entry)
      end)
    )
  end

  reflow()
end

--- Drop-in vim.notify replacement. Safe from fast-event contexts: the real
--- work always runs on the next main-loop tick.
---@param msg string
---@param level integer?
---@param opts table?
local function notify(msg, level, opts)
  level = level or levels.INFO
  msg = tostring(msg)

  vim.schedule(function()
    if is_suppressed(msg) then
      -- Skip default_notify too: it still echoes WARN/ERROR messages to the
      -- cmdline even when only :messages logging was wanted.
      return
    end

    -- Record to :messages so nothing is ever silently lost.
    pcall(default_notify, msg, level, opts)

    local ok, err = pcall(render, msg, level)
    if not ok then
      pcall(default_notify, ("notify: failed to render float (%s)"):format(err), levels.ERROR)
    end
  end)
end

vim.notify = notify

package.loaded[MODULE_NAME] = { default_notify = default_notify }

-- clear = true so re-sourcing replaces this generation's autocmds instead
-- of stacking a duplicate set.
local augroup = vim.api.nvim_create_augroup("mars_notify", { clear = true })

-- Timers keep firing across a `:qa` unless stopped explicitly; nothing
-- should touch the (possibly already-closing) UI during shutdown.
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = augroup,
  callback = function()
    for _, entry in ipairs(active) do
      if entry.timer then
        pcall(function()
          entry.timer:stop()
          entry.timer:close()
        end)
        entry.timer = nil
      end
    end
    active = {}
  end,
})

-- A float can also close because the user closed it by hand; drop it from
-- the stack so later notifications don't leave a gap.
vim.api.nvim_create_autocmd("WinClosed", {
  group = augroup,
  callback = function(ev)
    local win = tonumber(ev.match)
    for _, entry in ipairs(active) do
      if entry.win == win then
        dismiss(entry)
        break
      end
    end
  end,
})
