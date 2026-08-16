-- Misc insert-mode edit affordances: a semicolon-append shortcut, a
-- Spanish/Catalan accent input layer built on Neovim's own digraphs
-- (:help digraphs, :help i_CTRL-K) rather than a system keyboard-layout
-- switch, undo-preserving cursor moves, an undo-able backspace, `$` as a
-- word character for php/js/ts, and comment-leader autocontinuation
-- disabled repo-wide.

--- Appends `;` at the end of the current line, in both normal and insert
--- mode, unless the line already ends with one. Leaves the cursor in
--- insert mode afterwards, matching plain `A`.
local function append_semicolon()
  local line = vim.api.nvim_get_current_line()
  if line:sub(-1) ~= ";" then
    local keys = vim.api.nvim_replace_termcodes("<esc>A;", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

vim.keymap.set({ "n", "i" }, ";;", append_semicolon, { desc = "Append ; at end of line" })

-- Accents and other special characters for Spanish and Catalan, entered
-- via Neovim's digraph table instead of a system-level layout switch.
-- <C-k> alone (no second character supplied here) leaves the digraph
-- prompt open, so the following key the user types completes the pair;
-- e.g. <A-'> then `e` yields é, then `a` yields á, and so on for any
-- vowel. Mappings that already supply both digraph characters are
-- complete on their own.
vim.keymap.set("i", "<A-e>", "<C-k>Eu", { desc = "Insert €" })
vim.keymap.set("i", "<A-'>", "<C-k>'", { desc = "Acute accent, then a vowel (á é í ó ú)" })
vim.keymap.set("i", "<A-`>", "<C-k>`", { desc = "Grave accent, then a vowel (à è ò)" })
vim.keymap.set("i", "<A-;>", "<C-k>:", { desc = "Diaeresis, then a vowel (ü)" })
vim.keymap.set("i", "<A-n>", "<C-k>~n", { desc = "Insert ñ" })
vim.keymap.set("i", "<A-N>", "<C-k>~N", { desc = "Insert Ñ" })
vim.keymap.set("i", "<A-c>", "<C-k>,c", { desc = "Insert ç" })
vim.keymap.set("i", "<A-C>", "<C-k>,C", { desc = "Insert Ç" })
vim.keymap.set("i", "<A-1>", "<C-k>~!", { desc = "Insert ¡" })
vim.keymap.set("i", "<A-/>", "<C-k>~?", { desc = "Insert ¿" })
vim.keymap.set("i", "<A-.>", "<C-k>~.", { desc = "Insert · (Catalan l·l)" })

-- Move the cursor in insert mode without starting a new undo sequence
-- (<C-g>U tells Neovim the following cursor movement doesn't break the
-- current change, unlike leaving and re-entering insert mode with
-- <Esc>...i/a would).
vim.keymap.set("i", "<A-h>", "<C-g>U<Left>", { desc = "Left without breaking undo" })
vim.keymap.set("i", "<A-l>", "<C-g>U<Right>", { desc = "Right without breaking undo" })

-- Redefine backspace to start a new undo sequence first (<C-g>u), so a
-- run of backspaces is its own undo-able step instead of merging into
-- the surrounding insert.
vim.keymap.set("i", "<C-h>", "<C-g>u<C-h>", { desc = "Backspace as its own undo step" })

local augroup = vim.api.nvim_create_augroup("mars_insert", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "php", "javascript", "typescript" },
  desc = "Treat $variable as one word for w/*/etc. motions",
  callback = function()
    vim.opt_local.iskeyword:append("$")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  desc = "Strip auto comment-continuation (ftplugins/LSP tend to re-add c/r/o)",
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})
