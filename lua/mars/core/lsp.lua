-- Activates every native LSP config under lsp/*.lua (see :help lsp-config).
-- Each server is configured declaratively in its own file; dropping one in is
-- all it takes to enable it, so this list never has to be maintained by hand.

local names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
  names[#names + 1] = vim.fn.fnamemodify(file, ":t:r")
end

vim.lsp.enable(names)

-- Rounded borders and balanced sizing for LSP floating windows.
local float_defaults = {
  border = "rounded",
  max_width = 80,
  max_height = 16,
}

vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
  vim.lsp.handlers.hover(err, result, ctx, vim.tbl_extend("keep", config or {}, float_defaults))
end

vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
  vim.lsp.handlers.signature_help(
    err,
    result,
    ctx,
    vim.tbl_extend("keep", config or {}, {
      border = "rounded",
      max_width = 80,
      max_height = 12,
    })
  )
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mars_lsp_rename_keymap", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_rename, args.buf) then
      vim.keymap.set(
        "n",
        "grn",
        "<cmd>MarsRename<cr>",
        { buffer = args.buf, silent = true, desc = "Rename symbol (live preview)" }
      )
    end
  end,
})
