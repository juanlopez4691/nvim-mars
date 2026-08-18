-- Per-buffer guard that disables expensive features (syntax, treesitter,
-- LSP, spell, swapfile, folding, cursorline) once a file crosses either
-- threshold.

local MAX_FILESIZE = 1.5 * 1024 * 1024 -- 1.5 MB
local MAX_LINES = 5000

--- Line count only means anything once the buffer is loaded, so this is
--- only called from BufReadPost, never BufReadPre.
---@param buf integer
---@param file string
---@return boolean
local function is_bigfile(buf, file)
  local filesize = vim.fn.getfsize(file)
  local lines = vim.api.nvim_buf_line_count(buf)
  return filesize >= MAX_FILESIZE or lines >= MAX_LINES
end

local group = vim.api.nvim_create_augroup("mars_bigfile", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  pattern = "*",
  desc = "Disable expensive buffer-local features on very large files",
  callback = function(args)
    if not is_bigfile(args.buf, args.file) then
      return
    end

    -- LSP clients can attach after this callback already ran.
    vim.b[args.buf].mars_bigfile = true

    vim.bo[args.buf].syntax = "off"
    pcall(vim.treesitter.stop, args.buf)

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
      vim.lsp.buf_detach_client(args.buf, client.id)
    end

    vim.opt_local.spell = false
    vim.opt_local.swapfile = false
    vim.opt_local.foldmethod = "manual"
    vim.opt_local.cursorline = false
  end,
})

-- LSP servers attach asynchronously, after BufReadPost has already fired.
vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  desc = "Keep LSP clients off buffers flagged as big files",
  callback = function(args)
    if vim.b[args.buf].mars_bigfile then
      vim.lsp.buf_detach_client(args.buf, args.data.client_id)
    end
  end,
})
