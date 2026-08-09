-- Line-reordering and visual-mode indent ergonomics, using only native
-- Neovim commands:
-- `:move` (`:m`) for reordering, `==`/`gv=gv` to re-indent afterwards, and
-- `gv` to reselect after an indent.

-- Move the current line down/up by [count] lines (default 1), then
-- re-indent it. `v:count1` defaults to 1 when no count is given.
vim.keymap.set("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move line up" })

-- Move the selected lines down/up by [count] lines, then reselect ("gv")
-- and re-indent ("="); reselecting first is what makes `=` apply to the
-- moved lines instead of re-indenting whatever the cursor lands on.
vim.keymap.set("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move selection down" })
vim.keymap.set(
  "v",
  "<A-k>",
  ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv",
  { desc = "Move selection up" }
)

-- `<`/`>` in visual mode indent once and drop back to normal mode, which
-- makes repeated indenting tedious. Reselect ("gv") after each indent to
-- stay in visual mode instead.
vim.keymap.set("x", "<", "<gv", { desc = "Indent selection left, staying in visual mode" })
vim.keymap.set("x", ">", ">gv", { desc = "Indent selection right, staying in visual mode" })
