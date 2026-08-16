-- Insert-mode affordances: semicolon-append, Spanish/Catalan accents via
-- Neovim's digraphs (:help digraphs), undo-preserving cursor moves, an
-- undo-able backspace, `$` as a word char for php/js/ts, and comment
-- continuation disabled.

--- Appends `;` at end of line unless it already ends with one, leaving the
--- cursor in insert mode like plain `A`.
local function append_semicolon()
  local line = vim.api.nvim_get_current_line()
  if line:sub(-1) ~= ";" then
    local keys = vim.api.nvim_replace_termcodes("<esc>A;", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

vim.keymap.set({ "n", "i" }, ";;", append_semicolon, { desc = "Append ; at end of line" })

-- Accents via Neovim's digraph table. A lone `<C-k>` (e.g. `<A-'>`)
-- leaves the digraph prompt open, so the following vowel completes the
-- pair; mappings supplying both characters are complete on their own.
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

-- <C-g>U marks the cursor move as part of the current change, so moving in
-- insert mode doesn't start a new undo sequence.
vim.keymap.set("i", "<A-h>", "<C-g>U<Left>", { desc = "Left without breaking undo" })
vim.keymap.set("i", "<A-l>", "<C-g>U<Right>", { desc = "Right without breaking undo" })

-- <C-g>u starts a new undo sequence, so a backspace run is its own step.
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
