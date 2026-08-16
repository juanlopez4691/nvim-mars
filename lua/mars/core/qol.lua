-- Small editing quality-of-life autocmds: flash-highlight yanked text,
-- and restore the cursor to its
-- last-known position when reopening a previously-edited file. Both are
-- Neovim's own documented recipes (`:help lua-highlight`, `:help '"`) and
-- need no plugin.

local group = vim.api.nvim_create_augroup("mars_qol", { clear = true })

-- Briefly flash-highlight the yanked region after any yank/delete-into-
-- register operation, so it's visually obvious what was just grabbed.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Flash-highlight the yanked text region",
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Jump to the last-known cursor position (the `'"` mark) when reopening a
-- previously-edited file, if that position is still within the buffer.
-- Skipped for commit-message buffers, matching the reference config, since
-- git always opens those at line 1 intentionally.
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
