-- fzf-lua: fuzzy picker. No native Neovim API reproduces fuzzy-matched
-- file/grep/symbol lists (see AGENTS.md's approved exception list).

require("mars.pack").add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
})

-- Curated set of LSP symbol kinds worth surfacing in the filtered symbol
-- pickers below, trimming noise like Strings/Numbers/Booleans that rarely
-- matter when jumping around a codebase.
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

--- `regex_filter` for fzf-lua's LSP symbol pickers, despite the name, also
--- accepts a predicate function called per-entry, used here to filter by
--- `entry.kind` instead of matching against display text.
---@param entry { kind: string }
---@return boolean
local function filter_symbol_kinds(entry)
  return wanted_symbol_kinds[entry.kind] == true
end

local is_setup = false

--- Wrap a picker call so fzf-lua's `setup()` runs on first use rather than
--- at startup. Keymaps are the only entry point here (no event/ft/cmd to
--- hook via `mars.pack`'s `on()`), so the deferral lives in the wrapper
--- itself.
---@param fn fun(fzf_lua: table)
---@return fun()
local function use(fn)
  return function()
    if not is_setup then
      is_setup = true
      -- "default-title" labels each picker window with its name; otherwise
      -- fzf-lua's own defaults apply, including icon choices, left alone
      -- here rather than baked in from `vim.g.have_nerd_font`.
      require("fzf-lua").setup({ "default-title" })
    end
    fn(require("fzf-lua"))
  end
end

-- Find
vim.keymap.set(
  "n",
  "<leader>ff",
  use(function(fzf_lua)
    fzf_lua.files()
  end),
  { silent = true, desc = "Find: files" }
)

vim.keymap.set(
  "n",
  "<leader>fg",
  use(function(fzf_lua)
    fzf_lua.live_grep()
  end),
  { silent = true, desc = "Find: live grep" }
)

vim.keymap.set(
  "n",
  "<leader>fb",
  use(function(fzf_lua)
    fzf_lua.buffers()
  end),
  { silent = true, desc = "Find: buffers" }
)

vim.keymap.set(
  "n",
  "<leader>fr",
  use(function(fzf_lua)
    fzf_lua.oldfiles()
  end),
  { silent = true, desc = "Find: recent files" }
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

-- Code
vim.keymap.set(
  "n",
  "<leader>cs",
  use(function(fzf_lua)
    fzf_lua.lsp_document_symbols()
  end),
  { silent = true, desc = "Code: document symbols" }
)

vim.keymap.set(
  "n",
  "<leader>cS",
  use(function(fzf_lua)
    fzf_lua.lsp_document_symbols({ regex_filter = filter_symbol_kinds })
  end),
  { silent = true, desc = "Code: document symbols (filtered)" }
)

vim.keymap.set(
  "n",
  "<leader>cw",
  use(function(fzf_lua)
    fzf_lua.lsp_live_workspace_symbols()
  end),
  { silent = true, desc = "Code: workspace symbols" }
)
