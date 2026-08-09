-- Native completion via vim.lsp.completion (Neovim >= 0.11), buffer-word
-- matching, and path expansion. No completion plugin; see AGENTS.md's
-- Native-First Philosophy. Ghost-text/inline preview is not possible with
-- native completion; that's a known gap.

vim.o.completeopt = "menu,menuone,noselect,popup,fuzzy"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    vim.bo[ev.buf].complete = ".,w,b,u,t,i,kspell"
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})
