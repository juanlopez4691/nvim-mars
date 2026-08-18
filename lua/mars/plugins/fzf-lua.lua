-- fzf-lua: fuzzy picker. No native Neovim API reproduces fuzzy-matched
-- file/grep/symbol lists.

local M = {}

require("mars.pack").add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
})

-- LSP symbol kinds worth surfacing in the filtered symbol picker below;
-- trims noise like Strings/Numbers/Booleans that rarely matter when jumping.
local symbol_kinds = {
  "Class",
  "Closure",
  "Constant",
  "Constructor",
  "Enum",
  "Field",
  "Function",
  "Interface",
  "Method",
  "Module",
  "Namespace",
  "Package",
  "Parameter",
  "Property",
  "Struct",
  "Trait",
  "Variable",
}

local wanted_symbol_kinds = {}
for _, kind in ipairs(symbol_kinds) do
  wanted_symbol_kinds[kind] = true
end

--- fzf-lua's `regex_filter`, despite the name, also accepts a predicate
--- called per-entry, used here to filter by `entry.kind`.
---@param entry { kind: string }
---@return boolean
local function filter_symbol_kinds(entry)
  return wanted_symbol_kinds[entry.kind] == true
end

local is_setup = false

--- Run fzf-lua's `setup()` on first use rather than at startup. Keymaps are
--- the only entry point here (no event/ft/cmd to hook via `mars.pack.on`),
--- so the deferral lives in this wrapper. The window size comes from
--- `vim.g.mars_fzf_size` (fractions, e.g. `{ width = 0.8, height = 0.7 }`),
--- defaulting to fzf-lua's own 0.8 x 0.85.
---@param fn fun(fzf_lua: table)
---@return fun()
local function use(fn)
  return function()
    if not is_setup then
      is_setup = true
      -- "default-title" labels each picker window with its name; fzf-lua's
      -- other defaults (incl. icons) are left alone rather than baked in
      -- from `vim.g.have_nerd_font`.
      local size = type(vim.g.mars_fzf_size) == "table" and vim.g.mars_fzf_size or {}
      local opts = { "default-title" }
      opts.winopts = {
        width = size.width or 0.8,
        height = size.height or 0.85,
      }
      require("fzf-lua").setup(opts)
    end
    fn(require("fzf-lua"))
  end
end

M.use = use

-- Find: files to open and places to jump to.
vim.keymap.set(
  "n",
  "<leader>ff",
  use(function(fzf_lua)
    fzf_lua.files()
  end),
  { silent = true, desc = "Files" }
)

vim.keymap.set(
  "n",
  "<leader>fb",
  use(function(fzf_lua)
    fzf_lua.buffers()
  end),
  { silent = true, desc = "Buffers" }
)

vim.keymap.set(
  "n",
  "<leader>fr",
  use(function(fzf_lua)
    fzf_lua.oldfiles()
  end),
  { silent = true, desc = "Recent" }
)

-- Catch-all meta-picker: lists every registered fzf-lua picker as a fuzzable
-- entry, so the rest of these keymaps are discoverable from one place.
vim.keymap.set(
  "n",
  "<leader>fk",
  use(function(fzf_lua)
    fzf_lua.builtin()
  end),
  { silent = true, desc = "All Pickers" }
)

vim.keymap.set(
  "n",
  "<leader>fm",
  use(function(fzf_lua)
    fzf_lua.marks()
  end),
  { silent = true, desc = "Marks" }
)

vim.keymap.set(
  "n",
  "<leader>fj",
  use(function(fzf_lua)
    fzf_lua.jumps()
  end),
  { silent = true, desc = "Jumps" }
)

-- Git
vim.keymap.set(
  "n",
  "<leader>gs",
  use(function(fzf_lua)
    fzf_lua.git_status()
  end),
  { silent = true, desc = "Status" }
)

vim.keymap.set(
  "n",
  "<leader>gc",
  use(function(fzf_lua)
    fzf_lua.git_commits()
  end),
  { silent = true, desc = "Commits" }
)

vim.keymap.set(
  "n",
  "<leader>gb",
  use(function(fzf_lua)
    fzf_lua.git_branches()
  end),
  { silent = true, desc = "Branches" }
)

-- Search: text search.
vim.keymap.set(
  "n",
  "<leader>sg",
  use(function(fzf_lua)
    fzf_lua.live_grep()
  end),
  { silent = true, desc = "Live Grep" }
)

-- Grep word/selection; `sw` scopes to the project root, `sW` stays in the
-- cwd. Normal mode greps the word under the cursor, visual mode the selection.
local function project_root()
  return vim.fs.root(0, ".git") or vim.uv.cwd()
end

vim.keymap.set(
  "n",
  "<leader>sw",
  use(function(fzf_lua)
    fzf_lua.grep_cword({ search_paths = { project_root() } })
  end),
  { silent = true, desc = "Grep word under cursor (root)" }
)
vim.keymap.set(
  "x",
  "<leader>sw",
  use(function(fzf_lua)
    fzf_lua.grep_visual({ search_paths = { project_root() } })
  end),
  { silent = true, desc = "Grep selection (root)" }
)
vim.keymap.set(
  "n",
  "<leader>sW",
  use(function(fzf_lua)
    fzf_lua.grep_cword()
  end),
  { silent = true, desc = "Grep word under cursor (cwd)" }
)
vim.keymap.set(
  "x",
  "<leader>sW",
  use(function(fzf_lua)
    fzf_lua.grep_visual()
  end),
  { silent = true, desc = "Grep selection (cwd)" }
)

-- Grep open buffers: rg with `search_paths` fanned out to every named buffer.
-- `sb` differs by matching open-buffer lines instead (fzf-lua's `lines`).
local function grep_buffers()
  local paths = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" then
      paths[#paths + 1] = name
    end
  end
  return require("fzf-lua").grep({ search_paths = paths })
end

vim.keymap.set(
  "n",
  "<leader>sB",
  use(function(_fzf_lua)
    grep_buffers()
  end),
  { silent = true, desc = "Grep open buffers" }
)
vim.keymap.set(
  "n",
  "<leader>sb",
  use(function(fzf_lua)
    fzf_lua.lines()
  end),
  { silent = true, desc = "Buffer lines" }
)

-- Search history / resume the last picker.
vim.keymap.set(
  "n",
  "<leader>s/",
  use(function(fzf_lua)
    fzf_lua.search_history()
  end),
  { silent = true, desc = "Search history" }
)
vim.keymap.set(
  "n",
  "<leader>sR",
  use(function(fzf_lua)
    fzf_lua.resume()
  end),
  { silent = true, desc = "Resume last picker" }
)

-- Vim: pickers over Vim's own docs and state.
vim.keymap.set(
  "n",
  "<leader>vh",
  use(function(fzf_lua)
    fzf_lua.helptags()
  end),
  { silent = true, desc = "Help pages" }
)
vim.keymap.set(
  "n",
  "<leader>vM",
  use(function(fzf_lua)
    fzf_lua.man_pages()
  end),
  { silent = true, desc = "Man pages" }
)
vim.keymap.set(
  "n",
  "<leader>vu",
  use(function(fzf_lua)
    fzf_lua.undotree()
  end),
  { silent = true, desc = "Undo history" }
)
vim.keymap.set(
  "n",
  "<leader>va",
  use(function(fzf_lua)
    fzf_lua.autocmds()
  end),
  { silent = true, desc = "Autocmds" }
)
vim.keymap.set(
  "n",
  "<leader>vC",
  use(function(fzf_lua)
    fzf_lua.commands()
  end),
  { silent = true, desc = "Commands" }
)
vim.keymap.set(
  "n",
  "<leader>vk",
  use(function(fzf_lua)
    fzf_lua.keymaps()
  end),
  { silent = true, desc = "Keymaps" }
)
vim.keymap.set(
  "n",
  "<leader>vc",
  use(function(fzf_lua)
    fzf_lua.command_history()
  end),
  { silent = true, desc = "Command history" }
)
vim.keymap.set(
  "n",
  "<leader>vr",
  use(function(fzf_lua)
    fzf_lua.registers()
  end),
  { silent = true, desc = "Registers" }
)

-- Code
vim.keymap.set(
  "n",
  "<leader>cs",
  use(function(fzf_lua)
    fzf_lua.lsp_document_symbols()
  end),
  { silent = true, desc = "Document Symbols" }
)

vim.keymap.set(
  "n",
  "<leader>cS",
  use(function(fzf_lua)
    fzf_lua.lsp_document_symbols({ regex_filter = filter_symbol_kinds })
  end),
  { silent = true, desc = "Document Symbols (Filtered)" }
)

vim.keymap.set(
  "n",
  "<leader>cw",
  use(function(fzf_lua)
    fzf_lua.lsp_live_workspace_symbols()
  end),
  { silent = true, desc = "Workspace Symbols" }
)

return M
