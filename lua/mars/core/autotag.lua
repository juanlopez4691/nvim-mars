-- Native auto-close/auto-rename of HTML/JSX tags, replacing nvim-ts-autotag.
-- Treesitter-driven via TextChangedI (the parser needs the just-typed char
-- already in the buffer). Covers HTML/JSX tag-pair shapes only; Blade
-- directives have no HTML-style open/close node pairs to hook.

local VOID_ELEMENTS = {
  area = true,
  base = true,
  br = true,
  col = true,
  embed = true,
  hr = true,
  img = true,
  input = true,
  link = true,
  meta = true,
  source = true,
  track = true,
  wbr = true,
}

-- Tag-container node type -> { name_type = its name child's node type,
-- side = "open" | "close" }. HTML has `erroneous_end_tag` for a closing tag
-- whose name doesn't yet match its opener (the mid-rename state) handled
-- like a well-formed `end_tag`. JSX has no such distinction.
local TAG_CONTAINERS = {
  start_tag = { name_type = "tag_name", side = "open" },
  end_tag = { name_type = "tag_name", side = "close" },
  erroneous_end_tag = { name_type = "erroneous_end_tag_name", side = "close" },
  jsx_opening_element = { name_type = "identifier", side = "open" },
  jsx_closing_element = { name_type = "identifier", side = "close" },
}

-- Open-container node type -> closing types counting as "already matched",
-- and the reverse for the other direction.
local MATCHING_CLOSE_TYPES = {
  start_tag = { end_tag = true, erroneous_end_tag = true },
  jsx_opening_element = { jsx_closing_element = true },
}
local MATCHING_OPEN_TYPES = {
  end_tag = { start_tag = true },
  erroneous_end_tag = { start_tag = true },
  jsx_closing_element = { jsx_opening_element = true },
}

-- Re-entrancy guard: these edits re-trigger TextChangedI synchronously.
local applying = false

--- Returns `tag_node`'s direct child of type `name_type`, or nil.
---@param tag_node TSNode
---@param name_type string
---@return TSNode?
local function name_child(tag_node, name_type)
  for child in tag_node:iter_children() do
    if child:type() == name_type then
      return child
    end
  end
  return nil
end

--- If the cursor is right after a '>' that just completed a non-self-closing
--- opening tag with no matching close tag, insert the close tag without moving.
---@param buf integer
---@param win integer
local function maybe_close_tag(buf, win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row, col = cursor[1] - 1, cursor[2]
  if col == 0 then
    return
  end
  if vim.api.nvim_get_current_line():sub(col, col) ~= ">" then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return
  end
  pcall(parser.parse, parser)

  local tag_node = vim.treesitter.get_node({ bufnr = buf, pos = { row, col - 1 } })
  local spec
  while tag_node do
    spec = TAG_CONTAINERS[tag_node:type()]
    if spec and spec.side == "open" then
      break
    end
    spec = nil
    tag_node = tag_node:parent()
  end
  if not tag_node or not spec then
    return
  end

  -- Must be THIS tag's own closing '>', not one inside an attribute value.
  local _, _, erow, ecol = tag_node:range()
  if erow ~= row or ecol ~= col then
    return
  end

  local name = name_child(tag_node, spec.name_type)
  if not name then
    return
  end
  local tag_text = vim.treesitter.get_node_text(name, buf)
  if spec.name_type == "tag_name" and VOID_ELEMENTS[tag_text:lower()] then
    return
  end

  local element = tag_node:parent()
  if element then
    local close_types = MATCHING_CLOSE_TYPES[tag_node:type()]
    for child in element:iter_children() do
      if close_types[child:type()] then
        return
      end
    end
  end

  applying = true
  vim.api.nvim_buf_set_text(buf, row, col, row, col, { "</" .. tag_text .. ">" })
  vim.api.nvim_win_set_cursor(win, { row + 1, col })
  applying = false
end

--- If the cursor is inside a tag name whose paired tag's name has drifted,
--- rewrites the other one to match.
---@param buf integer
---@param win integer
local function maybe_sync_tag_name(buf, win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row, col = cursor[1] - 1, cursor[2]

  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return
  end
  pcall(parser.parse, parser)

  local node = vim.treesitter.get_node({ bufnr = buf, pos = { row, math.max(col - 1, 0) } })
  local parent = node and node:parent()
  if not node or not parent then
    return
  end

  local spec = TAG_CONTAINERS[parent:type()]
  if not spec or node:type() ~= spec.name_type then
    return
  end

  local element = parent:parent()
  if not element then
    return
  end

  local other_types = spec.side == "open" and MATCHING_CLOSE_TYPES[parent:type()] or MATCHING_OPEN_TYPES[parent:type()]

  local other_tag
  for child in element:iter_children() do
    if other_types[child:type()] then
      other_tag = child
      break
    end
  end
  local other_spec = other_tag and TAG_CONTAINERS[other_tag:type()]
  local other_name = other_spec and name_child(other_tag, other_spec.name_type)
  if not other_name then
    return
  end

  local this_text = vim.treesitter.get_node_text(node, buf)
  local other_text = vim.treesitter.get_node_text(other_name, buf)
  if this_text == other_text then
    return
  end

  local osrow, oscol, oerow, oecol = other_name:range()
  applying = true
  vim.api.nvim_buf_set_text(buf, osrow, oscol, oerow, oecol, { this_text })
  -- Keep the cursor anchored to the tag being typed when the rewritten tag
  -- sits before it on the same line.
  if osrow == row and oscol < col then
    local delta = #this_text - (oecol - oscol)
    vim.api.nvim_win_set_cursor(win, { row + 1, col + delta })
  end
  applying = false
end

vim.api.nvim_create_autocmd("TextChangedI", {
  group = vim.api.nvim_create_augroup("mars_autotag", { clear = true }),
  callback = function(ev)
    if applying then
      return
    end
    local win = vim.api.nvim_get_current_win()
    maybe_close_tag(ev.buf, win)
    maybe_sync_tag_name(ev.buf, win)
  end,
})
