-- Explicit clipboard yank/paste/replace keymaps. core/options.lua sets
-- `clipboard = ""`, so plain y/p stay on the unnamed register; these are
-- the opt-in path to the "+ register.

-- Copy & Paste group (prefix <leader>y; label in which-key.lua): `y` yanks
-- the line, `Y` to end of line, `p` pastes.
vim.keymap.set("n", "<leader>yy", '"+yy', { silent = true, desc = "Yank line to clipboard" })
vim.keymap.set({ "v", "x" }, "<leader>yy", '"+y', { silent = true, desc = "Yank selection to clipboard" })
vim.keymap.set("n", "<leader>yY", '"+y$', { silent = true, desc = "Yank to end of line to clipboard" })

-- Visual-mode paste deletes the selection into the unnamed register first,
-- clobbering a fresh yank; "_d avoids that.
vim.keymap.set("n", "<leader>yp", '"+p', { silent = true, desc = "Paste from clipboard" })
vim.keymap.set({ "v", "x" }, "<leader>yp", '"_d"+P', { silent = true, desc = "Paste replacing selection" })

--- Confirm-each substitution (:s/.../.../gc) of `text` across the buffer.
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

  -- \V (very-nomagic) makes the "/\\"-only escape sufficient: without it,
  -- regex-special chars in code ([0], `.`) would be matched, not literal.
  local ok, err = pcall(vim.cmd, ("%%s/\\V%s/%s/gc"):format(pattern, vim.fn.escape(replacement, "/\\")))
  if not ok then
    vim.notify(("Replace failed: %s"):format(err), vim.log.levels.ERROR)
  end
end

-- Delete the selection into the black hole register (leaving the unnamed
-- register alone) and drop into insert mode.
vim.keymap.set("x", "<leader>r", '"_c', { silent = true, desc = "Replace selection" })

vim.keymap.set("n", "<leader>R", function()
  replace_all(vim.fn.expand("<cword>"))
end, { silent = true, desc = "Replace all occurrences" })

vim.keymap.set("x", "<leader>R", function()
  -- Reselect ("gv") before yanking: the callback runs after leaving visual
  -- mode, and "v keeps the unnamed register untouched.
  vim.cmd('normal! gv"vy')
  local text = vim.fn.getreg("v")
  if type(text) ~= "string" then
    return
  end
  replace_all(text)
end, { silent = true, desc = "Replace all occurrences" })
