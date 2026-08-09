-- Manual snippet expansion via the native vim.snippet.expand(), for triggers
-- not covered by an attached LSP server's own completion items (which
-- already expand as a side effect of accepting them; no wiring needed for
-- that path). Data is vendored from friendly-snippets (MIT, see
-- lua/mars/lang/snippets/LICENSE) as static JSON, not a runtime plugin.
--
-- Jumping between tabstops afterwards reuses Neovim's own default <Tab>/
-- <S-Tab> vim.snippet.jump() mapping; this module only extends <Tab> to
-- also expand a matching trigger word before falling through to it.

local M = {}

---@type table<string, string[]>
local FILETYPE_FILES = {
  php = { "global", "php" },
  blade = { "global", "html", "blade", "blade-helpers", "blade-livewire", "blade-snippets" },
  twig = { "global", "html", "twig" },
  javascript = { "global", "javascript" },
  javascriptreact = { "global", "javascript" },
  typescript = { "global", "typescript" },
  typescriptreact = { "global", "typescript" },
  html = { "global", "html" },
  css = { "global", "css" },
  scss = { "global", "css" },
  markdown = { "global", "markdown" },
  lua = { "global", "lua" },
  dockerfile = { "global", "dockerfile" },
}

---@param name string
---@return table<string, { prefix: string|string[], body: string|string[] }>?
local function read_file(name)
  local files = vim.api.nvim_get_runtime_file(("lua/mars/lang/snippets/%s.json"):format(name), false)
  if not files[1] then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(files[1]), "\n"))
  if not ok then
    vim.notify(("Mars: failed to parse snippet file %s.json"):format(name), vim.log.levels.WARN)
    return nil
  end

  return decoded
end

---@type table<string, table<string, string>>
local cache = {}

---@param filetype string
---@return table<string, string> trigger to body text
local function triggers_for(filetype)
  if cache[filetype] then
    return cache[filetype]
  end

  local triggers = {}
  for _, name in ipairs(FILETYPE_FILES[filetype] or {}) do
    local decoded = read_file(name)
    if decoded then
      for _, entry in pairs(decoded) do
        local prefixes = type(entry.prefix) == "table" and entry.prefix or { entry.prefix }
        local body = type(entry.body) == "table" and table.concat(entry.body, "\n") or entry.body
        for _, prefix in ipairs(prefixes) do
          triggers[prefix] = body
        end
      end
    end
  end

  cache[filetype] = triggers
  return triggers
end

---@return string?
local function word_before_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  -- ":" is included because several vendored Blade snippets use a
  -- namespaced prefix (e.g. "b:extends", "lv:asset").
  return line:sub(1, col):match("([%w_%-:]+)$")
end

---@param len integer
local function delete_word_before_cursor(len)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_text(0, row - 1, col - len, row - 1, col, {})
end

--- <Tab> handler: jump an active snippet, else expand a matching trigger
--- word, else navigate the completion popup, else fall through to a literal
--- <Tab>.
function M.tab()
  if vim.snippet.active({ direction = 1 }) then
    vim.snippet.jump(1)
    return
  end

  local word = word_before_cursor()
  local body = word and triggers_for(vim.bo.filetype)[word]
  if body then
    delete_word_before_cursor(#word)
    vim.snippet.expand(body)
    return
  end

  if require("mars.core.completion").pum_tab() then
    return
  end

  vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "n", false)
end

vim.keymap.set({ "i", "s" }, "<Tab>", M.tab, { silent = true, desc = "Expand/jump snippet, else insert <Tab>" })

return M
