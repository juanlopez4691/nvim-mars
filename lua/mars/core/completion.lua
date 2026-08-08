-- Native LSP-driven completion (vim.lsp.completion, Neovim >= 0.11). No
-- completion plugin; see AGENTS.md's Native-First Philosophy. There's no
-- native equivalent of ghost-text/inline preview; that's a known gap.

vim.o.completeopt = "menu,menuone,noselect,popup,fuzzy"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})
