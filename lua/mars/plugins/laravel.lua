-- adalessa/laravel.nvim: Artisan/routes/make/resources pickers, an Artisan
-- Hub, a Command Center, and a resource-aware `gf` for Laravel projects (see
-- AGENTS.md's approved exception list).
--
-- nui.nvim, plenary.nvim, and nvim-nio below are laravel.nvim's own hard
-- runtime dependencies (UI primitives, file scanning, and async I/O
-- respectively). They're pulled in solely to satisfy laravel.nvim's own
-- `require()`s, not a general-purpose approval to reach for them elsewhere
-- in this config.

require("mars.pack").add({
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/nvim-neotest/nvim-nio" },
  { src = "https://github.com/adalessa/laravel.nvim" },
})

--- Whether the current working directory is a Laravel project root. Mirrors
--- the check laravel.nvim's own environment boot does internally, so this
--- gate never disagrees with the plugin about whether it should be active.
---@return boolean
local function is_laravel_project()
  return vim.fn.filereadable("artisan") == 1
end

--- Picks the "sail" environment when the project vendors Sail, so artisan
--- (and composer/npm/yarn) commands route through `vendor/bin/sail`. Every
--- other setup (Herd, Valet, native PHP, ...) falls through to the plugin's
--- own "local" default, running commands directly.
---@return string
local function detect_environment()
  if vim.fn.filereadable("vendor/bin/sail") == 1 then
    return "sail"
  end
  return "local"
end

local laravel_loaded = false

--- Runs laravel.nvim's setup exactly once. Safe to call repeatedly; the
--- FileType trigger below and every keymap call this before touching
--- `_G.Laravel`, so whichever fires first does the real work.
local function setup_laravel()
  if laravel_loaded then
    return
  end
  laravel_loaded = true

  require("laravel").setup({
    features = {
      pickers = {
        provider = "fzf-lua",
      },
    },
    environments = {
      default = detect_environment(),
      ask_on_boot = false,
    },
  })
end

-- `mars.pack.on()`'s triggers fire at most once, unconditionally; fine for
-- a plugin that always wants loading, but wrong here: a `php`/`blade`
-- buffer opened outside a Laravel project must not burn the only trigger.
-- The project check happens inside `config` instead; if it fails here, the
-- keymaps below still load laravel.nvim on demand the first time one is
-- used inside an actual Laravel project later in the same session.
require("mars.pack").on({
  ft = { "php", "blade" },
  config = function()
    if is_laravel_project() then
      setup_laravel()
    end
  end,
})

--- Builds a picker keymap callback: loads laravel.nvim on demand (in case
--- no `php`/`blade` buffer has triggered it yet) and runs the named picker,
--- or notifies instead of erroring when this isn't a Laravel project.
---@param name string
---@return fun()
local function picker(name)
  return function()
    if not is_laravel_project() then
      vim.notify("Not a Laravel project (no `artisan` found)", vim.log.levels.WARN)
      return
    end
    setup_laravel()
    -- selene: allow(global_usage)
    _G.Laravel.pickers[name]()
  end
end

--- Builds a keymap callback for a named Laravel command entry point
--- (Actions, Hub, Command Center, ...), with the same on-demand load and
--- non-Laravel guard as `picker()`.
---@param name string
---@return fun()
local function command(name)
  return function()
    if not is_laravel_project() then
      vim.notify("Not a Laravel project (no `artisan` found)", vim.log.levels.WARN)
      return
    end
    setup_laravel()
    -- selene: allow(global_usage)
    _G.Laravel.commands.run(name)
  end
end

vim.keymap.set("n", "<leader>ll", picker("laravel"), { desc = "Laravel Picker" })
vim.keymap.set("n", "<leader>la", picker("artisan"), { desc = "Artisan Picker" })
vim.keymap.set("n", "<leader>lr", picker("routes"), { desc = "Routes Picker" })
vim.keymap.set("n", "<leader>lm", picker("make"), { desc = "Make Picker" })
vim.keymap.set("n", "<leader>lc", picker("commands"), { desc = "Commands Picker" })
vim.keymap.set("n", "<leader>lo", picker("resources"), { desc = "Resources Picker" })
vim.keymap.set("n", "<leader>lt", command("actions"), { desc = "Actions" })
vim.keymap.set("n", "<leader>lu", command("hub"), { desc = "Hub" })
vim.keymap.set("n", "<leader>lp", command("command_center"), { desc = "Command Center" })
vim.keymap.set("n", "<c-g>", command("view:finder"), { desc = "View Finder" })

-- Defers to laravel.nvim's resource-aware jump (route()/view()/config()/
-- env()/Inertia::render() strings under the cursor) when this is a Laravel
-- project and the cursor is actually on one. Otherwise this is a plain,
-- non-recursive expr mapping that returns the literal keys "gf", so it
-- falls through to Neovim's built-in `gf` exactly as if this mapping
-- didn't exist.
vim.keymap.set("n", "gf", function()
  if not is_laravel_project() then
    return "gf"
  end

  setup_laravel()

  local ok, on_resource = pcall(function()
    -- selene: allow(global_usage)
    return _G.Laravel.app("gf").cursorOnResource()
  end)

  if ok and on_resource then
    return "<cmd>lua Laravel.commands.run('gf')<cr>"
  end

  return "gf"
end, { expr = true, desc = "Go to Resource" })
