-- Activates every native LSP config under lsp/*.lua (see :help lsp-config).
-- Each server is configured declaratively in its own file; dropping one in is
-- all it takes to enable it, so this list never has to be maintained by hand.

local names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
  names[#names + 1] = vim.fn.fnamemodify(file, ":t:r")
end

vim.lsp.enable(names)

-- Balanced sizing for LSP floating windows. Border style is read at
-- runtime from mars.ui.borders so local.lua overrides take effect.
vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
  vim.lsp.handlers.hover(
    err,
    result,
    ctx,
    vim.tbl_extend("keep", config or {}, {
      border = require("mars.ui.borders").style(),
      max_width = 80,
      max_height = 16,
    })
  )
end

vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
  vim.lsp.handlers.signature_help(
    err,
    result,
    ctx,
    vim.tbl_extend("keep", config or {}, {
      border = require("mars.ui.borders").style(),
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

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= "vtsls" then
      return
    end

    vim.keymap.set(
      "n",
      "gD",
      vim.lsp.buf.type_definition,
      { buffer = ev.buf, silent = true, desc = "Go to source definition" }
    )
    vim.keymap.set("n", "gR", function()
      vim.lsp.buf.references({ includeDeclaration = false })
    end, { buffer = ev.buf, silent = true, desc = "File references" })
    vim.keymap.set("n", "<leader>cM", function()
      vim.lsp.buf.code_action({
        context = { only = { "source.addMissingImports.ts" } },
        apply = true,
      })
    end, { buffer = ev.buf, silent = true, desc = "Add missing imports" })
    vim.keymap.set("n", "<leader>cD", function()
      vim.lsp.buf.code_action({
        context = { only = { "source.fixAll.ts" } },
        apply = true,
      })
    end, { buffer = ev.buf, silent = true, desc = "Fix-all diagnostics" })
    vim.keymap.set("n", "<leader>cV", function()
      vim.lsp.buf.execute_command({ command = "typescript.selectTypeScriptVersion", arguments = {} })
    end, { buffer = ev.buf, silent = true, desc = "Select TypeScript workspace version" })
  end,
})
