-- Native start screen, shown once on VimEnter when Neovim starts bare: no
-- file arguments, no piped-in stdin, and the initial buffer still empty and
-- unnamed. Never appears for `nvim somefile`, `nvim -`, or when restoring a
-- session that already opened buffers.
--
-- Every action below resolves its dependency lazily, at press time. None of
-- them are hard requirements of this module: a picker, a session module,
-- and a tool installer may or may not be wired up yet elsewhere in the
-- config. When one is missing the entry still renders (dimmed) and warns
-- instead of erroring when pressed -- see `with_fzf_lua`, `restore_session`,
-- and `open_tool_installer` below.

local ns = vim.api.nvim_create_namespace("mars.dashboard")

--- Nerd Font glyphs. Only ever read behind `vim.g.have_nerd_font` at draw
--- time (never memoized) -- see options.lua for why that flag can't be
--- resolved at require-time.
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
 __  __    _    ____  ____
|  \/  |  / \  |  _ \/ ___|
| |\/| | / _ \ | |_) \___ \
| |  | |/ ___ \|  _ < ___) |
|_|  |_/_/   \_\_| \_\____/
]],
  "\n",
  { trimempty = true }
)

--- Time-of-day greeting.
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
  return ("Good %s"):format(part)
end

--- Whether a plugin has been registered with `vim.pack` (via
--- `lua/mars/plugins/*.lua`), regardless of whether it has been loaded yet.
--- Side-effect-free -- safe to call just to decide whether to dim an entry.
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

--- Runs `fn(fzf_lua)` if fzf-lua is available, otherwise warns. fzf-lua is
--- an approved dependency (see AGENTS.md) but isn't added to this config
--- yet, so this is expected to warn today.
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

--- Session restore/list. Any future session module lives under
--- lua/mars/core/ and is auto-required at startup (see init.lua), so
--- checking `package.loaded` is enough to tell whether it exists -- no
--- probing require() needed.
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

--- Whether a tool installer command is registered (e.g. mason.nvim's
--- `:Mason`, once lua/mars/plugins/mason.lua exists).
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

--- Summarizes plugins registered via vim.pack. Native, so unlike the
--- entries above this always works.
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
---@field key string single buffer-local keymap trigger
---@field desc string label shown in the menu
---@field icon string Nerd Font glyph, only shown when vim.g.have_nerd_font
---@field available fun(): boolean cheap, side-effect-free readiness check
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

--- {width, height} last rendered at, so a resize event that doesn't
--- actually change this window's size (e.g. a split elsewhere) doesn't
--- trigger a redundant re-render.
local dashboard_size = nil

---@param action mars.dashboard.Action
---@return string text, string key_hl, string desc_hl
local function format_action(action)
  local icon = vim.g.have_nerd_font and (action.icon .. " ") or ""
  local text = ("[%s] %s%s"):format(action.key, icon, action.desc)
  if action.available() then
    return text, "Special", "Directory"
  end
  return text, "Comment", "Comment"
end

--- Builds the (unpadded) content lines plus per-line highlight ranges.
---@return string[] lines
---@return {line: integer, col_start: integer, col_end: integer, hl: string}[] highlights
local function build_content()
  local lines = {}
  local highlights = {}

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
    add("Title")
  end

  table.insert(lines, "")
  table.insert(lines, greeting())
  add("Comment")
  table.insert(lines, "")
  table.insert(lines, "")

  local function add_group(actions, label)
    if label then
      table.insert(lines, label)
      add("Comment")
      table.insert(lines, "")
    end
    for _, action in ipairs(actions) do
      local text, key_hl, desc_hl = format_action(action)
      table.insert(lines, text)
      local key_end = 1 + #action.key + 1 -- "[" + key + "]"
      add(key_hl, 0, key_end)
      add(desc_hl, key_end, -1)
    end
    table.insert(lines, "")
  end

  add_group(ACTIONS, nil)
  add_group(MAINTENANCE_ACTIONS, "Maintenance")

  -- Drop the trailing blank line added by the last group.
  lines[#lines] = nil

  return lines, highlights
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

---@param line string
---@return boolean
local function is_menu_line(line)
  return line:match("^%[") ~= nil or line == "Maintenance"
end

--- The window's current {width, height}, or nil if the dashboard isn't
--- shown anywhere. Compared before re-rendering on a resize event so a
--- resize that doesn't actually affect this window (e.g. a split
--- elsewhere) doesn't trigger a redundant re-render.
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
--- buffer, centered in whichever window currently shows it. Header and
--- greeting are centered within the menu block; menu entries stay
--- left-aligned within it, matching how the shared left margin is applied.
local function render()
  if not dashboard_buf or not vim.api.nvim_buf_is_valid(dashboard_buf) then
    return
  end
  local win = vim.fn.bufwinid(dashboard_buf)
  if win == -1 then
    return
  end

  local lines, highlights = build_content()
  local width = block_width(lines)
  local win_width = vim.api.nvim_win_get_width(win)
  local win_height = vim.api.nvim_win_get_height(win)
  local left_margin = math.max(0, math.floor((win_width - width) / 2))
  local top_margin = math.max(0, math.floor((win_height - #lines) / 2))

  ---@param line string
  local function line_pad(line)
    if is_menu_line(line) then
      return left_margin
    end
    return left_margin + math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))
  end

  local padded = {}
  for _ = 1, top_margin do
    table.insert(padded, "")
  end
  for _, line in ipairs(lines) do
    table.insert(padded, (" "):rep(line_pad(line)) .. line)
  end

  vim.bo[dashboard_buf].modifiable = true
  vim.api.nvim_buf_set_lines(dashboard_buf, 0, -1, false, padded)
  vim.bo[dashboard_buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(dashboard_buf, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    local text = lines[hl.line + 1]
    local pad = line_pad(text)
    local col_start = pad + hl.col_start
    -- -1 means "to end of line"; nvim_buf_set_extmark wants a real byte
    -- offset for end_col, so resolve it against the (unpadded) text length.
    local col_end = pad + (hl.col_end == -1 and #text or hl.col_end)
    vim.api.nvim_buf_set_extmark(dashboard_buf, ns, top_margin + hl.line, col_start, {
      end_col = col_end,
      hl_group = hl.hl,
    })
  end
end

--- Whether the current buffer/invocation is eligible for the dashboard: no
--- file arguments, no piped stdin, and an empty, unnamed, ordinary buffer.
--- Never hijacks `nvim somefile`.
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
  -- Catches piped stdin (and any other case where the buffer already holds
  -- more than its initial empty line): line2byte() of one past the last
  -- line is -1 only when there is nothing after it.
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
  -- Window-local options, captured before being clobbered below so they can
  -- be restored once the dashboard buffer is gone. Without this, opening a
  -- real file into the dashboard's own window (its usual find-file/recent
  -- actions do exactly that) silently inherits signcolumn="no" and the rest
  -- Window-local options don't reset just because the buffer changed.
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

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
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

  render()
  dashboard_size = current_size()
end

vim.api.nvim_create_autocmd("VimEnter", {
  desc = "Open the Mars dashboard for bare, argument-less invocations",
  nested = true,
  once = true,
  callback = function()
    if is_eligible() then
      open()
    end
  end,
})

-- Deferred to the next tick, not read synchronously inside the event: at
-- the exact moment WinResized/VimResized fires, Neovim's own internal
-- geometry recalculation for this window isn't always finished yet, so
-- nvim_win_get_width()/height() called immediately can still return a
-- stale, pre-resize value; render() would then center against the wrong
-- size, and nothing re-corrects it until another resize happens to come
-- along later and read the (by then genuinely current) size. Scheduling
-- gives Neovim's own resize handling a chance to finish first.
vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
  desc = "Re-center the Mars dashboard",
  callback = function()
    vim.schedule(function()
      local size = current_size()
      if size and not vim.deep_equal(size, dashboard_size) then
        dashboard_size = size
        render()
      end
    end)
  end,
})
