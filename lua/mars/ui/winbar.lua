-- Native winbar: relative filename, modified indicator, and a per-buffer
-- diagnostic summary. Suppressed on floating windows and non-file buffers
-- (help, quickfix, terminal, netrw), where a winbar looks broken.

local text = require("mars.text")

local M = {}

local severity = vim.diagnostic.severity

local nerd_font_icons = {
  [severity.ERROR] = "󰅚",
  [severity.WARN] = "󰀪",
  [severity.INFO] = "󰋽",
  [severity.HINT] = "󰌶",
}

local plain_icons = {
  [severity.ERROR] = "E:",
  [severity.WARN] = "W:",
  [severity.INFO] = "I:",
  [severity.HINT] = "H:",
}

--- Icon table for the current render, read each call since the nerd-font
--- flag may be set after this module loads or toggled at runtime.
---@return table<integer, string>
local function diagnostic_icons()
  return vim.g.have_nerd_font and nerd_font_icons or plain_icons
end

local expr = "%!v:lua.require'mars.ui.winbar'.render()"

--- Whether a window is floating (relative window, not a normal split).
---@param winid integer
---@return boolean
local function is_floating(winid)
  return vim.api.nvim_win_get_config(winid).relative ~= ""
end

--- Whether a buffer is a plain file buffer worth labeling: excludes
--- non-empty 'buftype' buffers and netrw listings, which keep 'buftype'
--- empty but set 'filetype'.
---@param bufnr integer
---@return boolean
local function is_file_buffer(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end
  return vim.bo[bufnr].filetype ~= "netrw"
end

--- Builds the diagnostic summary segment for a buffer, e.g. "E:2 W:1".
--- Empty when the buffer has no diagnostics.
---@param bufnr integer
---@return string
local function diagnostic_segment(bufnr)
  local counts = vim.diagnostic.count(bufnr)
  local icons = diagnostic_icons()
  local parts = {}
  for _, sev in ipairs({ severity.ERROR, severity.WARN, severity.INFO, severity.HINT }) do
    local count = counts[sev]
    if count and count > 0 then
      table.insert(parts, icons[sev] .. count)
    end
  end
  if #parts == 0 then
    return ""
  end
  return " " .. table.concat(parts, " ")
end

--- Renders the winbar for the window currently being redrawn. Called from
--- the 'winbar' expression, so it must resolve the target window via
--- `g:statusline_winid` rather than assuming the current one.
---@return string
function M.render()
  local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local name = vim.api.nvim_buf_get_name(bufnr)
  name = (name == "" and "[No Name]") or vim.fn.fnamemodify(name, ":~:.")
  local modified = vim.bo[bufnr].modified and " [+]" or ""

  -- '%' must be escaped so a filename can't be misread as a field specifier.
  return text.escape(name) .. modified .. diagnostic_segment(bufnr)
end

--- Sets or clears the window-local 'winbar' for a single window depending
--- on whether it's eligible (not floating, showing a file buffer).
---@param winid integer
local function update(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local eligible = not is_floating(winid) and is_file_buffer(bufnr)
  vim.wo[winid].winbar = eligible and expr or ""
end

local group = vim.api.nvim_create_augroup("mars_winbar", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "FileType", "TermOpen" }, {
  group = group,
  desc = "Show/hide the native winbar depending on window and buffer kind",
  callback = function()
    update(vim.api.nvim_get_current_win())
  end,
})

update(vim.api.nvim_get_current_win())

return M
