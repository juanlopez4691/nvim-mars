-- Activates every native LSP config under lsp/*.lua (see :help lsp-config).
-- Each server is configured declaratively in its own file; dropping one in is
-- all it takes to enable it, so this list never has to be maintained by hand.

local names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
  names[#names + 1] = vim.fn.fnamemodify(file, ":t:r")
end

vim.lsp.enable(names)
