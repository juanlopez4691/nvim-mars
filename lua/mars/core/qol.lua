-- Small editing quality-of-life autocmds, both Neovim's own documented
-- recipes (:help lua-highlight, :help '"'): flash-highlight yanked text
-- and restore the cursor to its last position when reopening a file.

local group = vim.api.nvim_create_augroup("mars_qol", { clear = true })

-- Native `gx` desc is long; re-bind its handler with a short label. Capture
-- the callback first, so the mapping reads the original, not itself.
local native_gx = vim.fn.maparg("gx", "n", false, true).callback
if native_gx then
  vim.keymap.set({ "n", "x" }, "gx", native_gx, { desc = "Open File or Link" })
end

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Flash-highlight the yanked text region",
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Restore the cursor to the `'"` mark if it's still within the buffer.
-- Skipped for commit-message buffers, which git always opens at line 1.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  desc = "Restore cursor to last-known position on reopen",
  callback = function(args)
    local buf = args.buf
    if vim.bo[buf].filetype == "gitcommit" or vim.b[buf].mars_last_loc then
      return
    end
    vim.b[buf].mars_last_loc = true

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
