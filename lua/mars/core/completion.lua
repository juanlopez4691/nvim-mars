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

---@param winid integer?
local function border_preview_window(winid)
  if not (winid and vim.api.nvim_win_is_valid(winid)) then
    return
  end
  local cfg = vim.api.nvim_win_get_config(winid)
  -- "none" means unbordered, not "already styled".
  if not cfg.border or cfg.border == "none" then
    cfg.border = require("mars.ui.borders").style()
  end
  -- Bump above the pum's own zindex (50) so the menu's scrollbar, drawn at
  -- the shared edge, can't overwrite the preview's left border.
  cfg.zindex = 51
  -- The C code sizes the borderless window to fit the screen exactly; adding
  -- a border would overflow and get clipped, so shrink the text area by the
  -- border's width when needed.
  local max_width = vim.o.columns - cfg.col - 2
  if cfg.width > max_width then
    cfg.width = math.max(1, max_width)
  end
  vim.api.nvim_win_set_config(winid, cfg)
end

vim.api.nvim_create_autocmd("CompleteChanged", {
  callback = function()
    vim.schedule(function()
      border_preview_window(vim.fn.complete_info().preview_winid)
    end)
  end,
})

if vim.api.nvim__complete_set then
  local orig_complete_set = vim.api.nvim__complete_set
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim__complete_set = function(...)
    local windata = orig_complete_set(...)
    if type(windata) == "table" then
      border_preview_window(windata.winid)
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
