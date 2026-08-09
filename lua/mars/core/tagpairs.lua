local M = {}

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

vim.api.nvim_create_autocmd("InsertLeave", {
  group = vim.api.nvim_create_augroup("mars_tagpairs_rename", { clear = true }),
  pattern = { "html", "javascriptreact", "typescriptreact", "vue", "blade", "php" },
  callback = function(ev)
    local lang = vim.treesitter.get_lang(ev.buf)
    if not lang then
      return
    end
    local ok, query = pcall(
      vim.treesitter.query.parse,
      lang,
      [[
      (element
        (start_tag (tag_name) @open)
        (end_tag (tag_name) @close))
    ]]
    )
    if not ok then
      return
    end
    local parser = vim.treesitter.get_parser(ev.buf, lang)
    local tree = parser:parse({ ev.buf })[1]
    if not tree then
      return
    end
    for _, match, _ in query:iter_matches(tree:root(), ev.buf) do
      local open_node = match.open
      local close_node = match.close
      if open_node and close_node then
        local open_text = vim.treesitter.get_node_text(open_node, ev.buf)
        local close_text = vim.treesitter.get_node_text(close_node, ev.buf)
        if open_text ~= close_text then
          local sr, sc, er, ec = close_node:range()
          vim.api.nvim_buf_set_text(ev.buf, sr, sc, er, ec, { open_text })
        end
      end
    end
  end,
})

return M
