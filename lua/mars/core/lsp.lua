-- Activates every native LSP config under lsp/*.lua (see :help lsp-config);
-- dropping a file in is all it takes to enable that server.

local names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
  names[#names + 1] = vim.fn.fnamemodify(file, ":t:r")
end

vim.lsp.enable(names)

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
