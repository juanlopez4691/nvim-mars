-- Editor options. Folding (foldmethod/foldexpr/foldlevel) belongs to the
-- treesitter/LSP folding setup, not here. completeopt belongs to the
-- native completion setup.

-- No reliable way to detect a terminal's font from Neovim; this is a
-- manual opt-in. Set to true if you have a Nerd Font installed; UI code
-- that wants file-type/git/diagnostic glyphs reads this instead of
-- re-detecting per module.
vim.g.have_nerd_font = false

-- Floating-window border style ("rounded", "single", "solid", "none").
-- Override in lua/mars/local.lua and call require("mars.ui.borders").setup().
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
opt.signcolumn = "yes"
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
-- Global fallback border for any float that doesn't set its own (e.g. LSP
-- hover/signature-help, vim.ui.select); see vim.lsp.util.open_floating_preview,
-- which falls back to this option when no explicit border is passed.
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
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
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

-- Auto-reload when a file changes on disk. `checktime` redraws any buffers
-- whose underlying file was modified externally; when multiple events fire
-- close together (e.g. BufEnter then FocusGained), the 300ms timer ensures
-- we only run one reload pass instead of N.
local checktime_timer = nil
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "TermLeave", "TermClose" }, {
  group = vim.api.nvim_create_augroup("mars_checktime", {}),
  callback = function()
    if checktime_timer then
      return
    end
    checktime_timer = vim.defer_fn(function()
      checktime_timer = nil
      -- Confirm before reloading if the buffer has unsaved changes
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
