-- `:checkhealth mars`; see :help health-dev for the require("mars.health")
-- discovery convention this file implements.

local M = {}

local function check_version()
  vim.health.start("Neovim version")
  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok(("Neovim %s"):format(tostring(vim.version())))
  else
    vim.health.error(("Mars requires Neovim >= 0.12, found %s"):format(tostring(vim.version())))
  end
end

---@param name string
---@param opts { required?: boolean, advice?: string }
local function check_binary(name, opts)
  opts = opts or {}
  if vim.fn.executable(name) == 1 then
    vim.health.ok(("`%s` found"):format(name))
  elseif opts.required then
    vim.health.error(("`%s` not found on PATH"):format(name), opts.advice)
  else
    vim.health.warn(("`%s` not found on PATH"):format(name), opts.advice)
  end
end

local function check_tools()
  vim.health.start("Required tools")
  check_binary("git", { required = true })
  check_binary("rg", { required = true, advice = "ripgrep (used for search/grep)" })
  check_binary("fd", { required = true, advice = "fd (used for file finding)" })

  vim.health.start("Language/feature tools")
  check_binary("lazygit", { advice = "used by the git terminal integration (M4)" })
  check_binary("php", { advice = "PHP toolchain (needed for PHP/Laravel development)" })
  check_binary("node", { advice = "Node toolchain (needed for JS/TS development)" })
  check_binary("tree-sitter", { advice = "tree-sitter CLI (used by nvim-treesitter to build parsers)" })

  vim.health.start("Dev tooling (contributing to Mars itself)")
  check_binary("stylua", { advice = "Lua formatter (see AGENTS.md)" })
  check_binary("selene", { advice = "Lua linter (see AGENTS.md)" })
end

function M.check()
  check_version()
  check_tools()
end

return M
