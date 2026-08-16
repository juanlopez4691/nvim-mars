-- Native start screen for bare invocations: no file arguments, no piped-in
-- stdin, initial buffer empty and unnamed. Menu actions resolve their
-- dependencies lazily at press time, so a missing picker/session/installer
-- renders dimmed and warns instead of erroring.

local ns = vim.api.nvim_create_namespace("mars.dashboard")

--- Nerd Font glyphs; only read behind `vim.g.have_nerd_font` at draw time.
local ICONS = {
  file = "",
  search = "",
  history = "",
  save = "",
  power = "",
  puzzle = "",
  wrench = "",
}

local HEADER = vim.split(
  [[
 __    __             __       __
/  \  /  |           /  \     /  |
██  \ ██ | __     __ ██  \   /██ |  ______    ______    _______
███  \██ |/  \   /  |███  \ /███ | /      \  /      \  /       |
████  ██ |██  \ /██/ ████  /████ | ██████  |/██████  |/███████/
██ ██ ██ | ██  /██/  ██ ██ ██/██ | /    ██ |██ |  ██/ ██      \
██ |████ |  ██ ██/   ██ |███/ ██ |/███████ |██ |       ██████  |
██ | ███ |   ███/    ██ | █/  ██ |██    ██ |██ |      /     ██/
██/   ██/     █/     ██/      ██/  ███████/ ██/       ███████/
]],
  "\n",
  { trimempty = true }
)

-- Right-pad all header lines to equal width: per-line centering would
-- otherwise misalign the letterforms, and trailing whitespace in the raw
-- string literal isn't reliably preserved.
do
  local max_width = 0
  for _, line in ipairs(HEADER) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end
  for i, line in ipairs(HEADER) do
    HEADER[i] = line .. (" "):rep(max_width - vim.fn.strdisplaywidth(line))
  end
end

-- Dedicated group (not "Title") so recoloring can't affect other "Title"
-- users; re-applied on ColorScheme since the color is hardcoded.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("mars_dashboard_header", { clear = true }),
  callback = function()
    vim.api.nvim_set_hl(0, "MarsDashboardHeader", { fg = "#c1440e", bold = true })
  end,
})
vim.api.nvim_set_hl(0, "MarsDashboardHeader", { fg = "#c1440e", bold = true })

--- Time-of-day greeting for the logged-in user.
---@return string
local function greeting()
  local hour = tonumber(vim.fn.strftime("%H")) or 12
  local part
  if hour < 5 then
    part = "night"
  elseif hour < 12 then
    part = "morning"
  elseif hour < 18 then
    part = "afternoon"
  else
    part = "evening"
  end
  local username = os.getenv("USER") or os.getenv("USERNAME") or "there"
  return ("Good %s, %s"):format(part, username)
end

--- Whether a plugin is registered with vim.pack, loaded or not.
---@param name string
---@return boolean
local function pack_has(name)
  for _, plugin in ipairs(vim.pack.get()) do
    if plugin.spec.name == name then
      return true
    end
  end
  return false
end

--- Runs fn(fzf_lua) if available, otherwise warns. Expected to warn until
--- fzf-lua is added to this config.
---@param fn fun(fzf_lua: table)
local function with_fzf_lua(fn)
  if not pack_has("fzf-lua") then
    vim.notify("fzf-lua isn't installed yet -- search is unavailable.", vim.log.levels.WARN)
    return
  end
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua is registered but failed to load.", vim.log.levels.WARN)
    return
  end
  fn(fzf_lua)
end

--- Whether a session module is loaded; auto-required startup modules show
--- up in package.loaded, so this needs no require() probe.
---@return boolean
local function has_session_module()
  return package.loaded["mars.core.session"] ~= nil
end

local function restore_session()
  local session = package.loaded["mars.core.session"]
  if type(session) ~= "table" or type(session.restore) ~= "function" then
    vim.notify("Session restore isn't available yet.", vim.log.levels.WARN)
    return
  end
  session.restore()
end

--- Whether a tool installer command (e.g. :Mason) is registered.
---@return boolean
local function has_tool_installer()
  return vim.fn.exists(":Mason") == 2
end

local function open_tool_installer()
  if not has_tool_installer() then
    vim.notify("No tool installer is configured yet.", vim.log.levels.WARN)
    return
  end
  vim.cmd("Mason")
end

--- Summarizes plugins registered via vim.pack.
local function show_plugin_status()
  local plugins = vim.pack.get()
  if #plugins == 0 then
    vim.notify("No plugins registered via vim.pack.", vim.log.levels.INFO)
    return
  end
  local lines = {}
  for _, plugin in ipairs(plugins) do
    table.insert(lines, ("%s (%s)"):format(plugin.spec.name, plugin.active and "active" or "inactive"))
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Plugin status" })
end

---@class mars.dashboard.Action
---@field key string buffer-local keymap trigger
---@field desc string label shown in the menu
---@field icon string Nerd Font glyph, only shown when vim.g.have_nerd_font
---@field available fun(): boolean side-effect-free readiness check
---@field run fun() the handler; degrades gracefully on its own when unready

---@type mars.dashboard.Action[]
local ACTIONS = {
  {
    key = "f",
    desc = "Find File",
    icon = ICONS.file,
    available = function()
      return pack_has("fzf-lua")
    end,
    run = function()
      with_fzf_lua(function(fzf_lua)
        fzf_lua.files()
      end)
    end,
  },
  {
    key = "g",
    desc = "Find Text",
    icon = ICONS.search,
    available = function()
      return pack_has("fzf-lua")
    end,
    run = function()
      with_fzf_lua(function(fzf_lua)
        fzf_lua.live_grep()
      end)
    end,
  },
  {
    key = "r",
    desc = "Recent Files",
    icon = ICONS.history,
    available = function()
      return pack_has("fzf-lua")
    end,
    run = function()
      with_fzf_lua(function(fzf_lua)
        fzf_lua.oldfiles()
      end)
    end,
  },
  {
    key = "s",
    desc = "Restore Session",
    icon = ICONS.save,
    available = has_session_module,
    run = restore_session,
  },
  {
    key = "q",
    desc = "Quit",
    icon = ICONS.power,
    available = function()
      return true
    end,
    run = function()
      vim.cmd("qa")
    end,
  },
}

---@type mars.dashboard.Action[]
local MAINTENANCE_ACTIONS = {
  {
    key = "p",
    desc = "Plugin Status",
    icon = ICONS.puzzle,
    available = function()
      return true
    end,
    run = show_plugin_status,
  },
  {
    key = "m",
    desc = "Tool Installer",
    icon = ICONS.wrench,
    available = has_tool_installer,
    run = open_tool_installer,
  },
}

--- Buffer currently holding the dashboard, if any.
local dashboard_buf = nil

--- {width, height} last rendered at, to skip redundant re-renders.
local dashboard_size = nil

--- 1-indexed buffer rows the cursor is allowed to rest on, updated on every
--- render() -- see the CursorMoved restriction set up in open().
---@type integer[]
local dashboard_action_rows = {}

--- Last row restrict_cursor() settled on, for travel direction; reset every
--- render since a resize renumbers rows. nil = no established direction.
---@type integer?
local dashboard_last_row = nil

--- 1-indexed buffer row -> the menu action's `run`, updated on every
--- render() -- see the <cr> handler set up in open().
---@type table<integer, fun()>
local dashboard_row_actions = {}

--- Description half of a menu line: icon (if any) plus label.
---@param action mars.dashboard.Action
---@return string desc, string key_hl, string desc_hl
local function format_action(action)
  local icon = vim.g.have_nerd_font and (action.icon .. " ") or ""
  local desc = icon .. action.desc
  if action.available() then
    return desc, "Special", "Directory"
  end
  return desc, "Comment", "Comment"
end

--- Builds the (unpadded) content lines plus per-line highlight ranges.
--- `header_count` marks where the header group ends and the menu group
--- begins (centered as independent blocks in render()); `menu_items` pairs
--- each actionable menu entry with its 1-indexed buffer position.
---@return string[] lines
---@return {line: integer, col_start: integer, col_end: integer, hl: string}[] highlights
---@return integer header_count
---@return {line: integer, run: fun()}[] menu_items
local function build_content()
  local lines = {}
  local highlights = {}
  local menu_items = {}

  local function add(hl, col_start, col_end)
    table.insert(highlights, {
      line = #lines - 1,
      col_start = col_start or 0,
      col_end = col_end or -1,
      hl = hl,
    })
  end

  for _, line in ipairs(HEADER) do
    table.insert(lines, line)
    add("MarsDashboardHeader")
  end

  table.insert(lines, "")
  table.insert(lines, greeting())
  add("Comment")

  local header_count = #lines

  table.insert(lines, "")
  table.insert(lines, "")

  -- Keys right-align at one shared column (widest desc across both groups),
  -- measured in display width, not bytes: Nerd Font glyphs vary in UTF-8
  -- byte length, so byte-based alignment would drift.
  local desc_width = 0
  for _, group in ipairs({ ACTIONS, MAINTENANCE_ACTIONS }) do
    for _, action in ipairs(group) do
      desc_width = math.max(desc_width, vim.fn.strdisplaywidth((format_action(action))))
    end
  end

  local function add_group(actions, title)
    table.insert(lines, title)
    add("MarsDashboardHeader")
    table.insert(lines, "")
    for _, action in ipairs(actions) do
      local desc, key_hl, desc_hl = format_action(action)
      local gap = desc_width - vim.fn.strdisplaywidth(desc) + 2 -- 2-space minimum gap before the key
      local text = desc .. (" "):rep(gap) .. action.key
      table.insert(lines, text)
      table.insert(menu_items, { line = #lines, run = action.run })
      -- Extmark columns are byte offsets; #desc and #action.key are correct here.
      add(desc_hl, 0, #desc)
      add(key_hl, #text - #action.key, -1)
    end
    table.insert(lines, "")
  end

  add_group(ACTIONS, "Actions")
  add_group(MAINTENANCE_ACTIONS, "Maintenance")

  -- Drop the trailing blank line added by the last group.
  lines[#lines] = nil

  return lines, highlights, header_count, menu_items
end

---@param lines string[]
---@return integer
local function block_width(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

--- The window's current {width, height}, or nil if not shown anywhere.
---@return integer[]? size {width, height}
local function current_size()
  if not dashboard_buf or not vim.api.nvim_buf_is_valid(dashboard_buf) then
    return nil
  end
  local win = vim.fn.bufwinid(dashboard_buf)
  if win == -1 then
    return nil
  end
  return { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win) }
end

--- Renders (or re-renders, e.g. after a resize) the dashboard into its
--- buffer, centered in whichever window shows it. Header and menu center as
--- two independent blocks on the window width -- the art is far wider than
--- the menu, and its own rows need a rigid shared left margin; the greeting
--- centers within the header block.
local function render()
  if not dashboard_buf or not vim.api.nvim_buf_is_valid(dashboard_buf) then
    return
  end
  local win = vim.fn.bufwinid(dashboard_buf)
  if win == -1 then
    return
  end

  local lines, highlights, header_count, menu_items = build_content()
  local win_width = vim.api.nvim_win_get_width(win)
  local win_height = vim.api.nvim_win_get_height(win)
  local top_margin = math.max(0, math.floor((win_height - #lines) / 2))

  dashboard_action_rows = {}
  dashboard_row_actions = {}
  dashboard_last_row = nil
  for _, item in ipairs(menu_items) do
    local row = top_margin + item.line
    table.insert(dashboard_action_rows, row)
    dashboard_row_actions[row] = item.run
  end

  local header_lines = { unpack(lines, 1, header_count) }
  local menu_lines = { unpack(lines, header_count + 1, #lines) }
  local header_width = block_width(header_lines)
  local menu_width = block_width(menu_lines)
  local header_margin = math.max(0, math.floor((win_width - header_width) / 2))
  local menu_margin = math.max(0, math.floor((win_width - menu_width) / 2))

  local greeting_line = header_count -- the last line of the header group

  ---@param i integer 1-indexed position in `lines`
  ---@param line string
  local function line_pad(i, line)
    if i > header_count then
      return menu_margin
    end
    if i == greeting_line then
      return header_margin + math.max(0, math.floor((header_width - vim.fn.strdisplaywidth(line)) / 2))
    end
    return header_margin
  end

  local padded = {}
  for _ = 1, top_margin do
    table.insert(padded, "")
  end
  for i, line in ipairs(lines) do
    table.insert(padded, (" "):rep(line_pad(i, line)) .. line)
  end

  vim.bo[dashboard_buf].modifiable = true
  vim.api.nvim_buf_set_lines(dashboard_buf, 0, -1, false, padded)
  vim.bo[dashboard_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(dashboard_buf, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    local i = hl.line + 1
    local text = lines[i]
    local pad = line_pad(i, text)
    local col_start = pad + hl.col_start
    -- -1 means "to end of line"; nvim_buf_set_extmark wants a real byte
    -- offset, so resolve it against the (unpadded) text length.
    local col_end = pad + (hl.col_end == -1 and #text or hl.col_end)
    vim.api.nvim_buf_set_extmark(dashboard_buf, ns, top_margin + hl.line, col_start, {
      end_col = col_end,
      hl_group = hl.hl,
    })
  end
end

--- Snaps the cursor onto the nearest actionable menu row, at its first
--- non-blank column (header and padding aren't interactive).
local function restrict_cursor()
  if #dashboard_action_rows == 0 or not dashboard_buf or not vim.api.nvim_buf_is_valid(dashboard_buf) then
    return
  end
  local win = vim.fn.bufwinid(dashboard_buf)
  if win == -1 then
    return
  end

  local target = vim.api.nvim_win_get_cursor(win)[1]
  local row = dashboard_row_actions[target] and target or nil

  -- Landed on a gap (blank line or group label): skip in the travel
  -- direction to the next actionable row, so j/k walks past a multi-line
  -- gap instead of always snapping to the numerically nearest edge.
  if not row and dashboard_last_row then
    if target > dashboard_last_row then
      for _, candidate in ipairs(dashboard_action_rows) do
        if candidate > target then
          row = candidate
          break
        end
      end
    else
      for i = #dashboard_action_rows, 1, -1 do
        if dashboard_action_rows[i] < target then
          row = dashboard_action_rows[i]
          break
        end
      end
    end
  end

  -- No direction established yet, or travel overshot an end: nearest by distance.
  if not row then
    row = dashboard_action_rows[1]
    for _, candidate in ipairs(dashboard_action_rows) do
      if math.abs(candidate - target) < math.abs(row - target) then
        row = candidate
      end
    end
  end

  dashboard_last_row = row

  local line = vim.api.nvim_buf_get_lines(dashboard_buf, row - 1, row, false)[1] or ""
  -- Skip past any leading Nerd Font icon: its bytes aren't ASCII
  -- word/punctuation, so this lands on the first label character.
  local col = (line:find("[%w%p]") or line:find("%S") or 1) - 1
  vim.api.nvim_win_set_cursor(win, { row, col })
end

--- Whether the current invocation is eligible: no file arguments, no piped
--- stdin, and an empty, unnamed, ordinary buffer. Never hijacks `nvim somefile`.
---@return boolean
local function is_eligible()
  if vim.fn.argc(-1) > 0 then
    return false
  end
  if vim.api.nvim_buf_get_name(0) ~= "" then
    return false
  end
  if vim.bo.buftype ~= "" then
    return false
  end
  if vim.bo.modified then
    return false
  end
  -- line2byte() one past the last line is -1 only when nothing follows it
  -- (catches piped stdin).
  if vim.fn.line2byte(vim.fn.line("$") + 1) ~= -1 then
    return false
  end
  return true
end

--- Turns the current (already-eligible) buffer into the dashboard: scratch,
--- unlisted, non-modifiable once drawn.
local function open()
  local buf = vim.api.nvim_get_current_buf()
  dashboard_buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "marsdashboard"

  local win = vim.api.nvim_get_current_win()
  -- Window-local options don't reset when the buffer changes, so a real
  -- file opened in this window (via find-file/recent) would inherit the
  -- dashboard's settings. Capture them to restore on wipeout.
  local saved_options = {
    number = vim.wo[win].number,
    relativenumber = vim.wo[win].relativenumber,
    cursorline = vim.wo[win].cursorline,
    list = vim.wo[win].list,
    signcolumn = vim.wo[win].signcolumn,
    foldenable = vim.wo[win].foldenable,
    spell = vim.wo[win].spell,
    wrap = vim.wo[win].wrap,
  }

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].list = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldenable = false
  vim.wo[win].spell = false
  vim.wo[win].wrap = false

  -- 'laststatus' is global, so save/restore it separately.
  local saved_laststatus = vim.o.laststatus
  vim.o.laststatus = 0

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      vim.o.laststatus = saved_laststatus
      if vim.api.nvim_win_is_valid(win) then
        for option, value in pairs(saved_options) do
          vim.wo[win][option] = value
        end
      end
    end,
  })

  for _, action in ipairs(ACTIONS) do
    vim.keymap.set("n", action.key, action.run, { buffer = buf, nowait = true, silent = true })
  end
  for _, action in ipairs(MAINTENANCE_ACTIONS) do
    vim.keymap.set("n", action.key, action.run, { buffer = buf, nowait = true, silent = true })
  end
  vim.keymap.set("n", "<cr>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local run = dashboard_row_actions[row]
    if run then
      run()
    end
  end, { buffer = buf, nowait = true, silent = true, desc = "Run the menu entry under the cursor" })

  render()
  dashboard_size = current_size()
  restrict_cursor()

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = restrict_cursor,
  })
end

vim.api.nvim_create_autocmd("VimEnter", {
  desc = "Open the Mars dashboard for bare, argument-less invocations",
  nested = true,
  once = true,
  callback = function()
    -- Read at call time: VimEnter fires after lua/mars/local.lua loads.
    if vim.g.mars_dashboard_enabled ~= false and is_eligible() then
      open()
    end
  end,
})

-- Deferred to the next tick: Neovim's own geometry recalculation for this
-- window isn't finished when the resize event fires, so an immediate read
-- can return a stale size and mis-center the dashboard until the next resize.
vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
  desc = "Re-center the Mars dashboard",
  callback = function()
    vim.schedule(function()
      local size = current_size()
      if size and not vim.deep_equal(size, dashboard_size) then
        dashboard_size = size
        render()
        restrict_cursor()
      end
    end)
  end,
})
