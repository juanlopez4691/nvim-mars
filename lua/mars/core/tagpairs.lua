-- Auto-close `</` tags on the typed `/`. Tag-name drift (renaming an open tag
-- and getting the close tag wrong) is handled by core/autotag.lua.

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = vim.api.nvim_create_augroup("mars_tagpairs", { clear = true }),
  pattern = { "html", "javascriptreact", "typescriptreact", "vue", "blade", "php" },
  callback = function(ev)
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col < 2 or line:sub(col, col) ~= "/" then
      return
    end
    local node = vim.treesitter.get_node({ bufnr = ev.buf })
    if not node then
      return
    end
    ---@type TSNode?
    local element = node
    while element do
      local type = element:type()
      if
        type == "element"
        or type == "start_tag"
        or type == "jsx_element"
        or type == "jsx_opening_element"
        or type == "vue_element"
      then
        local tag_name = nil
        for child in element:iter_children() do
          local ct = child:type()
          if ct == "tag_name" or ct == "name" or ct == "jsx_identifier" then
            tag_name = vim.treesitter.get_node_text(child, ev.buf)
            break
          end
        end
        if tag_name then
          local keys = vim.api.nvim_replace_termcodes(tag_name .. ">", true, true, true)
          vim.api.nvim_feedkeys(keys, "n", false)
          return
        end
      end
      element = element:parent()
    end
  end,
})
