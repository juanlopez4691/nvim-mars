-- adalessa/laravel.nvim: Artisan/routes/make/resources pickers, a command
-- center, and a resource-aware `gf` for Laravel projects.
--
-- nui.nvim, plenary.nvim, and nvim-nio are laravel.nvim's own hard runtime
-- dependencies (UI primitives, file scanning, async I/O), pulled in solely
-- to satisfy its `require()`s.

require("mars.pack").add({
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/nvim-neotest/nvim-nio" },
  { src = "https://github.com/adalessa/laravel.nvim" },
})

--- Whether the cwd is a Laravel project root. Mirrors laravel.nvim's own
--- internal check, so this gate never disagrees with the plugin.
---@return boolean
local function is_laravel_project()
  return vim.fn.filereadable("artisan") == 1
end

--- Picks the "sail" environment when the project vendors Sail, routing
--- artisan/composer/npm/yarn through `vendor/bin/sail`; everything else uses
--- the plugin's "local" default.
---@return string
local function detect_environment()
  if vim.fn.filereadable("vendor/bin/sail") == 1 then
    return "sail"
  end
  return "local"
end

local laravel_loaded = false

--- Runs laravel.nvim's setup exactly once.
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

-- `mars.pack.on()` fires its trigger at most once, unconditionally; a
-- php/blade buffer opened outside a Laravel project must not burn it, so the
-- project check lives inside `config`. If it fails, the keymaps below still
-- load laravel.nvim on demand the first time one runs in a real project.
require("mars.pack").on({
  ft = { "php", "blade" },
  config = function()
    if is_laravel_project() then
      setup_laravel()
    end
  end,
})

--- Loads laravel.nvim on demand and runs a named entry point, or notifies
--- instead of erroring when this isn't a Laravel project.
---@param invoke fun(name: string) runs `_G.Laravel.pickers[name]()` or
---  `_G.Laravel.commands.run(name)`
---@param name string
---@return fun()
local function laravel_entry(invoke, name)
  return function()
    if not is_laravel_project() then
      vim.notify("Not a Laravel project (no `artisan` found)", vim.log.levels.WARN)
      return
    end
    setup_laravel()
    -- selene: allow(global_usage)
    invoke(name)
  end
end

---@param name string
---@return fun()
local function picker(name)
  -- selene: allow(global_usage)
  return laravel_entry(function(n)
    _G.Laravel.pickers[n]()
  end, name)
end

---@param name string
---@return fun()
local function command(name)
  -- selene: allow(global_usage)
  return laravel_entry(function(n)
    _G.Laravel.commands.run(n)
  end, name)
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

-- Falls through to a literal "gf" when this isn't a Laravel project or the
-- cursor isn't on a resource, so Neovim's built-in `gf` runs exactly as if
-- this mapping didn't exist.
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
