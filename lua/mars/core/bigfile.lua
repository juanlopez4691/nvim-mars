-- Performance guard for very large files: syntax highlighting, Treesitter,
-- LSP, spellcheck, swapfiles, folding, and the cursorline all get more
-- expensive to maintain as a buffer grows, and none of them are worth
-- paying for on a multi-megabyte log or a five-figure-line generated file.
-- This turns them off per-buffer once a file crosses either threshold,
-- rather than requiring the user to notice the slowdown and disable things
-- by hand.

local MAX_FILESIZE = 1.5 * 1024 * 1024 -- 1.5 MB
local MAX_LINES = 5000

--- Whether a just-read buffer counts as "big" under either threshold. Line
--- count is only meaningful once the buffer is loaded, so this is only
--- ever called from BufReadPost, never BufReadPre.
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

    -- Flagged so the LspAttach guard below can recognize this buffer even
    -- when a client attaches after this callback already ran.
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

-- LSP servers routinely attach asynchronously, after BufReadPost has
-- already fired and detached whatever was attached at that point. Without
-- this, a client started moments later would go on to index a big file the
-- guard above just paid to stop treating as normal-sized.
vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  desc = "Keep LSP clients off buffers flagged as big files",
  callback = function(args)
    if vim.b[args.buf].mars_bigfile then
      vim.lsp.buf_detach_client(args.buf, args.data.client_id)
    end
  end,
})
