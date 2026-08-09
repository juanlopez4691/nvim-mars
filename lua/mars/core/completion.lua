-- Native completion via vim.lsp.completion (Neovim >= 0.11), buffer-word
-- matching, and path expansion. No completion plugin; see AGENTS.md's
-- Native-First Philosophy. Ghost-text/inline preview is not possible with
-- native completion; that's a known gap.

local M = {}

vim.o.completeopt = "menu,menuone,noselect,popup,fuzzy"

-- The popup menu gets its border from 'pumborder', applied centrally by
-- lua/mars/ui/borders.lua; pumwidth/pumheight in options.lua control sizing.

vim.cmd([[
  inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
  inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
]])

-- The documentation window shown next to the menu is the pum's preview
-- window. Neovim's C code creates it with an explicit border="none", and
-- 'pumborder' only covers the menu itself. Two creation paths, two hooks:
--
--   * Items with upfront documentation: the window appears on selection, so
--     a deferred CompleteChanged handler finds it via complete_info().
--   * Items whose docs arrive via completionItem/resolve: the window is
--     created later by vim.api.nvim__complete_set with no autocmd firing;
--     wrap it to style the window at creation time.
--
-- zindex is bumped above the pum's own (50) so the menu's scrollbar, drawn
-- at the shared edge, can't overwrite the preview's left border.

--- Left-pads the preview buffer's content by one cell, matching the menu's
--- built-in item inset so docs don't touch the border. The buffer is
--- core-managed and 'modifiable'-locked, so unlock it briefly. Skips content
--- whose first line already starts with a space (i.e. already padded; the
--- buffer is reused across items and rewritten by the C code on each update).
---@param bufnr integer?
local function pad_preview_buffer(bufnr)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  if not first or first == "" or first:sub(1, 1) == " " then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    lines[i] = " " .. line
  end
  local modifiable = vim.bo[bufnr].modifiable
  if not modifiable then
    vim.bo[bufnr].modifiable = true
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if not modifiable then
    vim.bo[bufnr].modifiable = false
  end
end

---@param winid integer?
local function border_preview_window(winid)
  if not (winid and vim.api.nvim_win_is_valid(winid)) then
    return
  end
  local cfg = vim.api.nvim_win_get_config(winid)
  local max_width = vim.o.columns - cfg.col - 2
  -- "none" means unbordered, not "already styled". When freshly bordering,
  -- widen by one cell to make room for the left padding; when the C code
  -- later resizes the window (border kept), only clamp.
  if not cfg.border or cfg.border == "none" then
    cfg.border = require("mars.ui.borders").style()
    cfg.width = math.min(cfg.width + 1, math.max(1, max_width))
  elseif cfg.width > max_width then
    -- The C code sizes the borderless window to fit the screen exactly;
    -- with a border on, that overflows and gets clipped.
    cfg.width = math.max(1, max_width)
  end
  -- Bump above the pum's own zindex (50) so the menu's scrollbar, drawn at
  -- the shared edge, can't overwrite the preview's left border.
  cfg.zindex = 51
  vim.api.nvim_win_set_config(winid, cfg)

  -- Wrap at word boundaries and align continuation lines with the padded
  -- text (breakindent respects the leading pad) instead of the window edge.
  vim.wo[winid].breakindent = true
  vim.wo[winid].linebreak = true
end

--- Styles the pum's documentation preview window: pads its buffer content
--- and borders the window.
---@param winid integer?
---@param bufnr integer?
local function style_preview_window(winid, bufnr)
  pad_preview_buffer(bufnr)
  border_preview_window(winid)
end

vim.api.nvim_create_autocmd("CompleteChanged", {
  callback = function()
    vim.schedule(function()
      local info = vim.fn.complete_info()
      style_preview_window(info.preview_winid, info.preview_bufnr)
    end)
  end,
})

if vim.api.nvim__complete_set then
  local orig_complete_set = vim.api.nvim__complete_set
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim__complete_set = function(...)
    local windata = orig_complete_set(...)
    if type(windata) == "table" then
      style_preview_window(windata.winid, windata.bufnr)
    end
    return windata
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    vim.bo[ev.buf].complete = ".,w,b,u,t,i,kspell"
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

--- Navigates to the next completion item when the popup is visible.
--- Called by lua/mars/lang/snippets.lua to chain completion navigation
--- before its literal-Tab fallback.
---@return boolean true if the popup was visible and navigation was performed
function M.pum_tab()
  if vim.fn.pumvisible() ~= 1 then
    return false
  end
  vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
  return true
end

return M
