-- Editor options. Folding (foldmethod/foldexpr/foldlevel) belongs to the
-- treesitter/LSP folding setup; completeopt to the native completion setup.

-- No reliable way to detect a terminal's font; manual opt-in. UI code that
-- wants glyphs reads this at point of use.
vim.g.have_nerd_font = false

-- Floating-window border style; override in lua/mars/local.lua.
vim.g.mars_border_style = "rounded"

local opt = vim.opt

-- Editing
opt.clipboard = ""
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.shiftround = true
opt.smartindent = true
opt.formatoptions = "jcroqlnt"

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "nosplit"
opt.grepprg = "rg --vimgrep"
opt.grepformat = "%f:%l:%c:%m"

-- UI
opt.number = true -- relativenumber is toggled dynamically based on mode/window focus
-- "auto:1-2" keeps the gutter at 1 column unless a line needs both a
-- gitsigns marker and a diagnostic sign at once; with one fixed slot they
-- compete and the lower-priority one silently disappears.
opt.signcolumn = "auto:1-2"
opt.termguicolors = true
opt.laststatus = 3
opt.showmode = false
opt.ruler = false
opt.pumheight = 12
opt.pumwidth = 25
opt.winminwidth = 5
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
  extends = "…",
}
opt.fillchars = {
  diff = "╱",
  eob = " ",
}
opt.conceallevel = 2
opt.linebreak = true
opt.wrap = false
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.smoothscroll = true
opt.mouse = "a"
opt.confirm = true
-- Global fallback border for floats that don't set their own (LSP hover/
-- signature-help, vim.ui.select); see vim.lsp.util.open_floating_preview.
opt.winborder = "rounded"

-- Splits
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"

-- Files and history
opt.undofile = true
opt.undolevels = 10000
opt.autowrite = true
opt.updatetime = 200
opt.timeoutlen = 300
opt.jumpoptions = "view"
opt.wildmode = "longest:full,full"
opt.virtualedit = "block"
opt.shortmess:append({ W = true, I = true, c = true, C = true })
opt.spelllang = { "en" }

-- Backup, scoped under this appname's own state dir
local backup_dir = vim.fn.stdpath("state") .. "/backup"
if vim.fn.isdirectory(backup_dir) == 0 then
  vim.fn.mkdir(backup_dir, "p")
end
opt.backupdir = backup_dir
opt.backup = true

-- Unused providers
vim.g.loaded_perl_provider = 0

-- Fix markdown indentation settings
vim.g.markdown_recommended_style = 0

-- Auto-reload on external change. When several events fire close together
-- (BufEnter then FocusGained), the 300ms timer runs one reload pass, not N.
local checktime_timer = nil
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "TermLeave", "TermClose" }, {
  group = vim.api.nvim_create_augroup("mars_checktime", {}),
  callback = function()
    if checktime_timer then
      return
    end
    checktime_timer = vim.defer_fn(function()
      checktime_timer = nil
      if vim.bo.modified then
        local choice = vim.fn.confirm("File changed on disk. Reload?", "&Yes\n&No", 2)
        if choice == 1 then
          vim.cmd("checktime")
        end
      else
        vim.cmd("checktime")
      end
    end, 300)
  end,
})
