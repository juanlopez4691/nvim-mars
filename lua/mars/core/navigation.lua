-- Treesitter textobject navigation: ]f/[f, ]c/[c, ]a/[a plus uppercase
-- variants, replacing nvim-treesitter-textobjects. Queries the buffer's
-- parse tree for matching node types and jumps to the closest match.

--- Node types per motion group. Language-agnostic: types that don't exist
--- in the current language are silent no-ops.
local GROUP_TYPES = {
  f = {
    "function_definition",
    "function_declaration",
    "method_definition",
    "method_declaration",
    "arrow_function",
    "function_expression",
  },
  c = {
    "class_definition",
    "class_declaration",
    "interface_declaration",
    "struct_declaration",
    "trait_declaration",
    "enum_declaration",
  },
  a = {
    "formal_parameters",
    "arguments",
    "argument_list",
    "parameter_list",
    "object_pattern",
  },
}

---@class MarsNavigation.Position
---@field lnum integer 1-indexed line
---@field col integer 0-indexed column

---@class MarsNavigation.Node : MarsNavigation.Position
---@field end_lnum integer 1-indexed end line
---@field end_col integer 0-indexed end column

--- Nodes matching any of `types` in the buffer's tree, sorted by start.
---@param buf integer
---@param types string[]
---@return MarsNavigation.Node[]
local function query_nodes(buf, types)
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang then
    return {}
  end

  -- One invalid node type fails the whole query, so each pattern is
  -- probe-parsed and dropped if the grammar doesn't know it.
  local patterns = {}
  for _, t in ipairs(types) do
    local pattern = "(" .. t .. ") @nav"
    if pcall(vim.treesitter.query.parse, lang, pattern) then
      patterns[#patterns + 1] = pattern
    end
  end
  if #patterns == 0 then
    return {}
  end

  local query = vim.treesitter.query.parse(lang, table.concat(patterns, "\n"))

  local parser = vim.treesitter.get_parser(buf, lang)
  if not parser then
    return {}
  end
  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  ---@type MarsNavigation.Node[]
  local nodes = {}
  -- iter_matches maps each capture id to a *list* of nodes (quantified
  -- captures); every pattern here binds a single node, so take the first.
  for _, match, _ in query:iter_matches(tree:root(), buf) do
    for _, node_list in pairs(match) do
      local node = node_list[1]
      if node then
        local sr, sc, er, ec = node:range()
        nodes[#nodes + 1] = {
          lnum = sr + 1,
          col = sc,
          end_lnum = er + 1,
          end_col = ec,
        }
      end
    end
  end

  return nodes
end

--- First non-whitespace position inside `node`'s body, skipping the
--- declaration signature line; falls back to the node start if empty.
---@param buf integer
---@param node MarsNavigation.Node
---@return MarsNavigation.Position
local function body_position(buf, node)
  if node.lnum >= node.end_lnum then
    return { lnum = node.lnum, col = node.col }
  end

  local lines = vim.api.nvim_buf_get_lines(buf, node.lnum, node.end_lnum, false)

  for i = 2, #lines do
    local line = lines[i]
    local non_ws = line:match("^%s*()%S")
    if non_ws then
      return { lnum = node.lnum + i - 1, col = non_ws - 1 }
    end
  end

  return { lnum = node.lnum, col = node.col }
end

--- Finds the closest node strictly before `lnum`,`col`.
---@param nodes MarsNavigation.Node[]
---@param lnum integer 1-indexed
---@param col integer 0-indexed
---@return MarsNavigation.Node?
local function closest_before(nodes, lnum, col)
  local best = nil
  for _, node in ipairs(nodes) do
    if node.lnum > lnum or (node.lnum == lnum and node.col >= col) then
      break
    end
    best = node
  end
  return best
end

--- Finds the closest node strictly after `lnum`,`col`.
---@param nodes MarsNavigation.Node[]
---@param lnum integer 1-indexed
---@param col integer 0-indexed
---@return MarsNavigation.Node?
local function closest_after(nodes, lnum, col)
  for _, node in ipairs(nodes) do
    if node.lnum > lnum or (node.lnum == lnum and node.col > col) then
      return node
    end
  end
  return nil
end

--- Builds a navigation function for one motion group and direction.
---@param group "f" | "c" | "a"
---@param direction "next" | "prev"
---@param target "start" | "body"
---@return fun()
local function make_nav(group, direction, target)
  return function()
    local buf = vim.api.nvim_get_current_buf()
    local nodes = query_nodes(buf, GROUP_TYPES[group])
    if #nodes == 0 then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local c_lnum, c_col = cursor[1], cursor[2]

    local hit
    if direction == "next" then
      hit = closest_after(nodes, c_lnum, c_col)
    else
      hit = closest_before(nodes, c_lnum, c_col)
    end

    if not hit then
      return
    end

    local pos = target == "body" and body_position(buf, hit) or { lnum = hit.lnum, col = hit.col }

    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(0, { pos.lnum, pos.col })
  end
end

local function desc(group, direction, target)
  local motion = direction == "next" and "Next" or "Previous"
  local style = target == "start" and "start" or ""
  local labels = {
    f = "function",
    c = "class",
    a = "parameter",
  }
  return ("%s %s %s"):format(motion, labels[group], style):gsub("%s+$", "")
end

for _, pair in ipairs({ { "]", "next" }, { "[", "prev" } }) do
  local prefix, direction = pair[1], pair[2]

  vim.keymap.set(
    "n",
    prefix .. "f",
    make_nav("f", direction, "body"),
    { silent = true, desc = desc("f", direction, "body") }
  )
  vim.keymap.set(
    "n",
    prefix .. "F",
    make_nav("f", direction, "start"),
    { silent = true, desc = desc("f", direction, "start") }
  )
  vim.keymap.set(
    "n",
    prefix .. "c",
    make_nav("c", direction, "body"),
    { silent = true, desc = desc("c", direction, "body") }
  )
  vim.keymap.set(
    "n",
    prefix .. "C",
    make_nav("c", direction, "start"),
    { silent = true, desc = desc("c", direction, "start") }
  )
  vim.keymap.set(
    "n",
    prefix .. "a",
    make_nav("a", direction, "body"),
    { silent = true, desc = desc("a", direction, "body") }
  )
  vim.keymap.set(
    "n",
    prefix .. "A",
    make_nav("a", direction, "start"),
    { silent = true, desc = desc("a", direction, "start") }
  )
end
