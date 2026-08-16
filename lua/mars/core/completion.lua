-- Native completion (vim.lsp.completion), buffer-word matching, and path
-- expansion. Menu border comes from 'pumborder' (lua/mars/ui/borders.lua);
-- pumwidth/pumheight live in options.lua.

local M = {}

vim.o.completeopt = "menu,menuone,noselect,popup,fuzzy"

-- Keymaps

vim.cmd([[
  inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
  inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
]])

-- <C-f>/<C-b> page the docs preview while the menu is open. Changing another
-- window is forbidden (E523) during an insert-mode expr mapping, so the
-- scroll is deferred. noremap so the fallback runs the built-in action.
---@param key string
---@param scroll_cmd string
---@return function
local function scroll_preview(key, scroll_cmd)
  return function()
    local winid = vim.fn.pumvisible() == 1 and vim.fn.complete_info().preview_winid or nil
    if winid and vim.api.nvim_win_is_valid(winid) then
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(winid) then
          pcall(vim.fn.win_execute, winid, scroll_cmd)
        end
      end)
      return ""
    end
    return key
  end
end

vim.keymap.set(
  "i",
  "<C-f>",
  scroll_preview("<C-f>", "normal! \6"),
  { expr = true, desc = "Scroll completion docs down" }
)
vim.keymap.set("i", "<C-b>", scroll_preview("<C-b>", "normal! \2"), { expr = true, desc = "Scroll completion docs up" })

-- Item decoration

-- Kind icons gated on vim.g.have_nerd_font, read per request (never cached).
local KIND_ICONS = {
  Text = "󰉿",
  Method = "󰆧",
  Function = "󰊕",
  Constructor = "󰒓",
  Field = "󰜢",
  Variable = "󰀫",
  Class = "󰠱",
  Interface = "󱡠",
  Module = "󰅩",
  Property = "󰜢",
  Unit = "󰑭",
  Value = "󰎠",
  Enum = "󰦨",
  Keyword = "󰌋",
  Snippet = "󱄽",
  Color = "󰏘",
  File = "󰈙",
  Reference = "󰈇",
  Folder = "󰉋",
  EnumMember = "󰦨",
  Constant = "󰏿",
  Struct = "󰙅",
  Event = "󱐋",
  Operator = "󰆕",
  TypeParameter = "󰬛",
}

-- Kind-to-highlight map, tinting the label like colorful-menu does for
-- blink.cmp. Undefined groups render as plain text.
local KIND_HLGROUPS = {
  Method = "@function",
  Function = "@function",
  Constructor = "@constructor",
  Field = "@property",
  Property = "@property",
  Variable = "@variable",
  Class = "@type",
  Interface = "@type",
  Struct = "@type",
  Enum = "@type",
  TypeParameter = "@type",
  EnumMember = "@constant",
  Constant = "@constant",
  Value = "@constant",
  Unit = "@number",
  Keyword = "@keyword",
  Operator = "@operator",
  Event = "@operator",
  Module = "@module",
  File = "@string.special.path",
  Folder = "@string.special.path",
  Color = "@constant",
  Snippet = "@string.special",
  Reference = "@markup.link",
}

local KIND_NAMES = vim.lsp.protocol.CompletionItemKind
local DEPRECATED = vim.lsp.protocol.CompletionTag.Deprecated

--- Decorates an LSP completion item for vim.lsp.completion's convert hook:
--- kind icon prefix, "[LSP]" source label, and a kind-tinted label.
---@param item lsp.CompletionItem
---@return table
local function convert_item(item)
  local kind_name = KIND_NAMES[item.kind] or "Text"
  local converted = { menu = "[LSP]" }

  if vim.g.have_nerd_font then
    local icon = KIND_ICONS[kind_name] or KIND_ICONS.Text
    local detail = vim.tbl_get(item, "labelDetails", "detail") or ""
    converted.abbr = ("%s %s%s"):format(icon, item.label, detail)
    converted.kind = ""
  end

  -- Don't clobber core's deprecation strikethrough with a kind tint.
  if not (item.deprecated or vim.list_contains(item.tags or {}, DEPRECATED)) then
    converted.abbr_hlgroup = KIND_HLGROUPS[kind_name]
    converted.kind_hlgroup = KIND_HLGROUPS[kind_name]
  end

  return converted
end

-- Documentation window styling

-- The pum's preview window gets border="none" from Neovim's C code, and
-- 'pumborder' only covers the menu. Two creation paths, two hooks: the
-- CompleteChanged handler for upfront docs, and a nvim__complete_set wrap
-- for docs arriving via completionItem/resolve (no autocmd fires).

--- Left-pads the preview buffer by one cell to match the menu's item inset.
--- The buffer is core-managed and 'modifiable'-locked, so unlock briefly.
--- Skips content already padded (the buffer is reused across items).
---@param bufnr integer?
local function pad_preview_buffer(bufnr)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
  if not first or first == "" or first:sub(1, 1) == " " then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    lines[i] = " " .. line
  end
  local modifiable = vim.bo[bufnr].modifiable
  if not modifiable then
    vim.bo[bufnr].modifiable = true
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if not modifiable then
    vim.bo[bufnr].modifiable = false
  end
end

---@param winid integer?
local function border_preview_window(winid)
  if not (winid and vim.api.nvim_win_is_valid(winid)) then
    return
  end
  local cfg = vim.api.nvim_win_get_config(winid)
  local max_width = vim.o.columns - cfg.col - 2
  -- "none" means unbordered, not "already styled". Freshly bordering widens
  -- by one cell for the left padding; later C-code resizes only get clamped.
  if not cfg.border or cfg.border == "none" then
    cfg.border = require("mars.ui.borders").style()
    cfg.width = math.min(cfg.width + 1, math.max(1, max_width))
  elseif cfg.width > max_width then
    cfg.width = math.max(1, max_width)
  end
  -- Bump above the pum's zindex (50) so its scrollbar can't overwrite the
  -- preview's left border.
  cfg.zindex = 51
  vim.api.nvim_win_set_config(winid, cfg)

  -- Wrap at word boundaries, aligning continuation lines with the padded text.
  vim.wo[winid].breakindent = true
  vim.wo[winid].linebreak = true
end

--- Styles the pum's documentation preview window: pads its buffer content
--- and borders the window.
---@param winid integer?
---@param bufnr integer?
local function style_preview_window(winid, bufnr)
  pad_preview_buffer(bufnr)
  border_preview_window(winid)
end

-- pcall: a cosmetic failure must never break completion.
vim.api.nvim_create_autocmd("CompleteChanged", {
  callback = function()
    vim.schedule(function()
      local info = vim.fn.complete_info()
      pcall(style_preview_window, info.preview_winid, info.preview_bufnr)
    end)
  end,
})

if vim.api.nvim__complete_set then
  local orig_complete_set = vim.api.nvim__complete_set
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim__complete_set = function(...)
    local windata = orig_complete_set(...)
    if type(windata) == "table" then
      pcall(style_preview_window, windata.winid, windata.bufnr)
    end
    return windata
  end
end

-- Ghost-text preview

-- With 'noselect', menu selection never touches the buffer; show the rest of
-- the selected item's text as dimmed ghost text instead.
vim.api.nvim_set_hl(0, "MarsCompletionGhostText", { link = "Comment", default = true })

local ghost_ns = vim.api.nvim_create_namespace("mars_completion_ghost_text")

--- Clears any ghost-text extmark in the current buffer.
local function clear_ghost_text()
  vim.api.nvim_buf_clear_namespace(0, ghost_ns, 0, -1)
end

--- The identifier characters before the cursor (what the menu matches).
---@return string
local function typed_prefix()
  local col = vim.fn.col(".")
  local line = vim.api.nvim_get_current_line()
  return line:sub(1, col - 1):match("[%w_]*$") or ""
end

--- Renders `word`'s untyped suffix as inline virtual text at the cursor.
--- Skipped when `word` isn't a literal continuation of the typed text:
--- under 'fuzzy' matching a non-prefix item would preview the wrong text.
---@param word string?
local function show_ghost_text(word)
  clear_ghost_text()
  if not word or word == "" then
    return
  end

  local prefix = typed_prefix()
  if prefix == "" or word:sub(1, #prefix) ~= prefix then
    return
  end
  local suffix = word:sub(#prefix + 1)
  if suffix == "" then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_extmark(0, ghost_ns, cursor[1] - 1, cursor[2], {
    virt_text = { { suffix, "MarsCompletionGhostText" } },
    virt_text_pos = "inline",
  })
end

vim.api.nvim_create_autocmd("CompleteChanged", {
  callback = function()
    pcall(show_ghost_text, vim.tbl_get(vim.v.event, "completed_item", "word"))
  end,
})

vim.api.nvim_create_autocmd({ "CompleteDone", "InsertLeave" }, {
  callback = clear_ghost_text,
})

-- LSP activation

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
    vim.bo[ev.buf].complete = ".,w,b,u,t,i,kspell"
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true, convert = convert_item })
    end
  end,
})

-- Public API

--- Selects the next completion item when the popup is visible. Called by
--- lua/mars/lang/snippets.lua before its literal-Tab fallback.
---@return boolean true if the popup was visible and navigation was performed
function M.pum_tab()
  if vim.fn.pumvisible() ~= 1 then
    return false
  end
  vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
  return true
end

return M
