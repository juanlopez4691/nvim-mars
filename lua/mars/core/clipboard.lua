-- Clipboard-explicit yank/paste and replace keymaps. core/options.lua sets
-- `clipboard = ""` (not `unnamedplus`), so plain y/p/Y/d stay on the
-- unnamed register and never silently touch the system clipboard. These
-- mappings are the explicit, opt-in path to the "+ register for when the
-- system clipboard is actually wanted.

-- Yank to the system clipboard.
vim.keymap.set({ "n", "v", "x" }, "<leader>y", '"+y', { silent = true, desc = "Yank to clipboard" })
vim.keymap.set("n", "<leader>yy", '"+yy', { silent = true, desc = "Yank line to clipboard" })
vim.keymap.set("n", "<leader>Y", '"+y$', { silent = true, desc = "Yank to end of line to clipboard" })

-- Paste from the system clipboard. Plain visual-mode paste replaces the
-- selection by deleting it into the unnamed register first, which would
-- clobber whatever was just yanked there; deleting into the black hole
-- register ("_d) before putting the clipboard contents ("+P) avoids that.
vim.keymap.set("n", "<leader>p", '"+p', { silent = true, desc = "Paste from clipboard" })
vim.keymap.set({ "v", "x" }, "<leader>p", '"_d"+P', { silent = true, desc = "Paste from clipboard" })

--- Prompts for replacement text and runs a confirm-each substitution
--- (:s/.../.../gc) across the whole buffer for every occurrence of `text`.
--- Interactive confirmation lets the user skip or bail on individual
--- matches instead of committing to a blind buffer-wide replace.
---@param text string
local function replace_all(text)
  if text == "" then
    vim.notify("Nothing to replace", vim.log.levels.WARN)
    return
  end

  local pattern = (vim.fn.escape(text, "/\\"):gsub("\n", "\\n"))
  local replacement = vim.fn.input(("Replace %q with: "):format(text))
  if replacement == "" then
    return
  end

  vim.notify("Confirm each match: [y]es [n]o [a]ll [q]uit [l]ast", vim.log.levels.INFO)

  -- \V (very-nomagic) makes the "/\\"-only escape above sufficient: without
  -- it, regex-special characters that are common in code (e.g. `[0]`, a
  -- `.` property access) would be interpreted instead of matched literally.
  local ok, err = pcall(vim.cmd, ("%%s/\\V%s/%s/gc"):format(pattern, vim.fn.escape(replacement, "/\\")))
  if not ok then
    vim.notify(("Replace failed: %s"):format(err), vim.log.levels.ERROR)
  end
end

-- Replace the current visual selection in place: delete it into the black
-- hole register (so the unnamed register is left alone) and drop into
-- insert mode to type the replacement.
vim.keymap.set("x", "<leader>r", '"_c', { silent = true, desc = "Replace selection" })

-- Replace every occurrence of the word under the cursor, or of the current
-- visual selection, buffer-wide.
vim.keymap.set("n", "<leader>R", function()
  replace_all(vim.fn.expand("<cword>"))
end, { silent = true, desc = "Replace all occurrences" })

vim.keymap.set("x", "<leader>R", function()
  -- The callback runs after leaving visual mode, so reselect ("gv") before
  -- yanking into register v, keeping the unnamed register untouched.
  vim.cmd('normal! gv"vy')
  local text = vim.fn.getreg("v")
  if type(text) ~= "string" then
    return
  end
  replace_all(text)
end, { silent = true, desc = "Replace all occurrences" })
