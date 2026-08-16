-- Blade and Antlers have no parser in nvim-treesitter's standard set, so map
-- them onto the "html" parser for basic tag/attribute highlighting.

vim.filetype.add({
  pattern = {
    ["%.blade%.php$"] = "blade",
    ["%.antlers%.html$"] = "antlers",
  },
})

vim.treesitter.language.register("html", { "blade", "antlers" })

-- treesitter.lua only knows about parser installs, not this html fallback
-- mapping, so start highlighting for these filetypes here.
local group = vim.api.nvim_create_augroup("mars_blade", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "blade", "antlers" },
  callback = function()
    vim.treesitter.start()
  end,
})
