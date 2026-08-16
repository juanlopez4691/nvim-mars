-- Activates every native LSP config under lsp/*.lua (see :help lsp-config);
-- dropping a file in is all it takes to enable that server.

local names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
  names[#names + 1] = vim.fn.fnamemodify(file, ":t:r")
end

vim.lsp.enable(names)

-- Call-hierarchy browsing (incoming/outgoing calls) as a fuzzy picker on
-- `gai`/`gao`, bound buffer-local only when an attached client supports the
-- method. fzf-lua loads on first use via the plugins wrapper, so no startup
-- dependency.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mars_lsp_call_hierarchy", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end
    local fzf = require("mars.plugins.fzf-lua")
    if client:supports_method(vim.lsp.protocol.Methods.callHierarchy_incomingCalls, ev.buf) then
      vim.keymap.set(
        "n",
        "gai",
        fzf.use(function(fzf_lua)
          fzf_lua.lsp_incoming_calls()
        end),
        { buffer = ev.buf, silent = true, desc = "LSP incoming calls" }
      )
    end
    if client:supports_method(vim.lsp.protocol.Methods.callHierarchy_outgoingCalls, ev.buf) then
      vim.keymap.set(
        "n",
        "gao",
        fzf.use(function(fzf_lua)
          fzf_lua.lsp_outgoing_calls()
        end),
        { buffer = ev.buf, silent = true, desc = "LSP outgoing calls" }
      )
    end
  end,
})

-- Border is read at runtime from mars.ui.borders so local.lua overrides apply.
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

-- Native LSP defaults (see vim/_core/defaults.lua) carry code-string descs
-- like "vim.lsp.buf.document_symbol()". Rebinding the same keys to the same
-- functions with human-readable descs keeps the keys native while making
-- which-key menus legible.
vim.keymap.set({ "n", "x" }, "gra", vim.lsp.buf.code_action, { desc = "Code Action" })
vim.keymap.set("n", "grr", vim.lsp.buf.references, { desc = "References" })
vim.keymap.set("n", "gri", vim.lsp.buf.implementation, { desc = "Implementation" })
vim.keymap.set("n", "grt", vim.lsp.buf.type_definition, { desc = "Type Definition" })
vim.keymap.set("n", "grx", vim.lsp.codelens.run, { desc = "Run Codelens" })
vim.keymap.set("n", "gO", vim.lsp.buf.document_symbol, { desc = "Document Symbols" })
vim.keymap.set({ "i", "s" }, "<C-S>", vim.lsp.buf.signature_help, { desc = "Signature Help" })

-- `K` is bound buffer-locally by core only when an attached client supports
-- hover and the buffer has no `keywordprg` of its own, so override it the
-- same way (on LspAttach, capability- and keywordprg-guarded); rebinding a
-- global `K` would hijack the key in non-LSP buffers.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("mars_lsp_hover_keymap", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if
      client
      and client:supports_method(vim.lsp.protocol.Methods.textDocument_hover, args.buf)
      and vim.bo[args.buf].keywordprg == ""
    then
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = args.buf, silent = true, desc = "Hover" })
    end
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
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

--- Jumps to a single location, or sends several to the quickfix list.
---@param locations lsp.Location[]|lsp.LocationLink[]?
---@param encoding "utf-8"|"utf-16"|"utf-32"
local function open_locations(locations, encoding)
  if not locations or #locations == 0 then
    vim.notify("No locations found", vim.log.levels.INFO)
    return
  end
  local items = vim.lsp.util.locations_to_items(locations, encoding)
  if #items == 1 then
    vim.cmd.edit(items[1].filename)
    vim.api.nvim_win_set_cursor(0, { items[1].lnum, items[1].col - 1 })
  else
    vim.fn.setqflist({}, " ", { title = "LSP", items = items })
    vim.cmd.copen()
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= "vtsls" then
      return
    end

    -- goToSourceDefinition resolves through .d.ts back to source, unlike
    -- `type_definition` which stops at the type's own declaration.
    vim.keymap.set("n", "gD", function()
      local win = vim.api.nvim_get_current_win()
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      client:exec_cmd({
        command = "typescript.goToSourceDefinition",
        arguments = { params.textDocument.uri, params.position },
      }, { bufnr = ev.buf }, function(err, result)
        if not err then
          open_locations(result, client.offset_encoding)
        end
      end)
    end, { buffer = ev.buf, silent = true, desc = "Go to source definition" })

    -- Files referencing the current file, distinct from `grr`, which finds
    -- references to the symbol under the cursor.
    vim.keymap.set("n", "gR", function()
      client:exec_cmd({
        command = "typescript.findAllFileReferences",
        arguments = { vim.uri_from_bufnr(ev.buf) },
      }, { bufnr = ev.buf }, function(err, result)
        if not err then
          open_locations(result, client.offset_encoding)
        end
      end)
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
