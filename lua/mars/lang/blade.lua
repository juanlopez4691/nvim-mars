-- Blade (Laravel) and Antlers (Statamic) are both HTML-embedded templating
-- languages with no dedicated parser in nvim-treesitter's standard set (see
-- lua/mars/plugins/treesitter.lua's parser install list). Rather than leave
-- either filetype without any highlighting at all, this module maps them
-- onto the "html" parser so tags/attributes still light up; the templating
-- syntax itself just reads as plain text.

vim.filetype.add({
  pattern = {
    ["%.blade%.php$"] = "blade",
    ["%.antlers%.html$"] = "antlers",
  },
})

vim.treesitter.language.register("html", { "blade", "antlers" })

-- treesitter.lua starts highlighting itself for the filetypes it lists, but
-- "blade"/"antlers" aren't among them (it only knows about parser installs,
-- not this fallback mapping); so start highlighting for them here instead.
-- This runs alongside, not in place of, that module's own FileType autocmd.
local group = vim.api.nvim_create_augroup("mars_blade", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "blade", "antlers" },
  callback = function()
    vim.treesitter.start()
  end,
})
