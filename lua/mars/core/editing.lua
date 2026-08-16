-- Line-reordering and stay-in-visual-mode indent, done natively with
-- `:move`, `==` and `gv`.

-- Move the current line down/up by [count] lines (default 1), then
-- re-indent. `v:count1` defaults to 1 when no count is given.
vim.keymap.set("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move line up" })

-- Move the selected lines, then reselect ("gv") before re-indenting so `=`
-- applies to the moved lines, not whatever the cursor lands on.
vim.keymap.set("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move selection down" })
vim.keymap.set(
  "v",
  "<A-k>",
  ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv",
  { desc = "Move selection up" }
)

-- `<`/`>` in visual mode drop back to normal after one indent; reselect
-- ("gv") to stay in visual mode.
vim.keymap.set("x", "<", "<gv", { desc = "Indent Left (stay in visual)" })
vim.keymap.set("x", ">", ">gv", { desc = "Indent Right (stay in visual)" })
