-- Auto-highlights the symbol under the cursor via
-- `textDocument/documentHighlight` (the recipe at :help
-- vim.lsp.buf.document_highlight()), wired per-buffer on LspAttach and
-- torn down on LspDetach once no remaining client still supports it.
--
-- `]r`/`[r` jump between highlights; the literal `]]`/`[[` from the
-- upstream recipe is avoided because those are Neovim's native section
-- motions (:help ]]).

local method = vim.lsp.protocol.Methods.textDocument_documentHighlight

local augroup = vim.api.nvim_create_augroup("mars_lsp_references", { clear = true })

--- The namespace `vim.lsp.util` places document-highlight extmarks under;
--- `nvim_create_namespace` returns the same id for a name every time.
local reference_ns = vim.api.nvim_create_namespace("nvim.lsp.references")

--- Builds a `]r`/`[r` handler jumping to the next/previous highlighted
--- reference, wrapping per 'wrapscan'.
---@param direction "next"|"prev"
---@return fun()
local function jump_reference(direction)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, reference_ns, 0, -1, {})
    if #marks == 0 then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local cur_row, cur_col = cursor[1] - 1, cursor[2]

    local target
    if direction == "next" then
      for _, mark in ipairs(marks) do
        local row, col = mark[2], mark[3]
        if row > cur_row or (row == cur_row and col > cur_col) then
          target = mark
          break
        end
      end
    else
      for i = #marks, 1, -1 do
        local mark = marks[i]
        local row, col = mark[2], mark[3]
        if row < cur_row or (row == cur_row and col < cur_col) then
          target = mark
          break
        end
      end
    end

    if not target then
      if not vim.o.wrapscan then
        vim.notify("No more references", vim.log.levels.INFO)
        return
      end
      target = direction == "next" and marks[1] or marks[#marks]
    end

    vim.api.nvim_win_set_cursor(0, { target[2] + 1, target[3] })
  end
end

--- Wires up the highlight/clear autocmds and `]r`/`[r` keymaps for one buffer.
---@param bufnr integer
local function attach(bufnr)
  if vim.b[bufnr].mars_lsp_references_attached then
    return
  end
  vim.b[bufnr].mars_lsp_references_attached = true

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = augroup,
    buffer = bufnr,
    desc = "LSP: highlight references under cursor",
    callback = function()
      vim.lsp.buf.document_highlight()
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    group = augroup,
    buffer = bufnr,
    desc = "LSP: clear reference highlights",
    callback = function()
      vim.lsp.buf.clear_references()
    end,
  })

  vim.keymap.set("n", "]r", jump_reference("next"), { buffer = bufnr, silent = true, desc = "Next Reference" })
  vim.keymap.set("n", "[r", jump_reference("prev"), { buffer = bufnr, silent = true, desc = "Previous Reference" })
end

--- Tears down the autocmds/keymaps/highlights from `attach`, once no
--- remaining client on the buffer supports document highlight.
---@param bufnr integer
local function detach(bufnr)
  if not vim.b[bufnr].mars_lsp_references_attached then
    return
  end

  vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
  pcall(vim.keymap.del, "n", "]r", { buffer = bufnr })
  pcall(vim.keymap.del, "n", "[r", { buffer = bufnr })
  vim.lsp.util.buf_clear_references(bufnr)
  vim.b[bufnr].mars_lsp_references_attached = nil
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = augroup,
  desc = "LSP: wire up reference highlighting for capable clients",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method(method, args.buf) then
      attach(args.buf)
    end
  end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  group = augroup,
  desc = "LSP: tear down reference highlighting once unsupported",
  callback = function(args)
    local bufnr = args.buf
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
      if client.id ~= args.data.client_id and client:supports_method(method, bufnr) then
        return
      end
    end
    detach(bufnr)
  end,
})
