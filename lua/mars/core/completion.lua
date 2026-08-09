-- Native completion via vim.lsp.completion (Neovim >= 0.11), buffer-word
-- matching, and path expansion. No completion plugin; see AGENTS.md's
-- Native-First Philosophy. Ghost-text/inline preview is not possible with
-- native completion; that's a known gap.

local M = {}

vim.o.completeopt = "menu,menuone,noselect,popup,fuzzy"

vim.cmd([[
  inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
  inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
]])

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
