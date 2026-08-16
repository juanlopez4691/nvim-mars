-- Native diagnostics for filetypes needing a CLI linter outside the LSP
-- protocol, plus a manual :Lint command. JS/TS/Vue are intentionally absent:
-- lsp/eslint.lua already publishes ESLint diagnostics over LSP, so a CLI
-- runner here would just duplicate that.

local tools = require("mars.lang.tools")

local M = {}

--- Own namespace so these diagnostics stay independent of LSP-published ones.
local ns = vim.api.nvim_create_namespace("mars_lint")

--- Parses a phpcs `--report=json` payload into vim.diagnostic items.
--- phpcs may write deprecation noise to stdout ahead of the JSON report, so
--- anything before the first "{" is discarded; line/column are converted
--- from phpcs's 1-indexed values and ERROR/WARNING maps to severity.
---@param output string Raw phpcs stdout
---@return vim.Diagnostic[]
function M.parse_phpcs(output)
  local brace = output:find("{", 1, true)
  if not brace then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, output:sub(brace))
  if not ok or type(decoded) ~= "table" or type(decoded.files) ~= "table" then
    return {}
  end

  local diagnostics = {}
  for _, file in pairs(decoded.files) do
    for _, message in ipairs(file.messages or {}) do
      table.insert(diagnostics, {
        lnum = (message.line or 1) - 1,
        col = (message.column or 1) - 1,
        end_lnum = (message.line or 1) - 1,
        end_col = (message.column or 1) - 1,
        severity = message.type == "ERROR" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
        message = message.message or "",
        source = "phpcs",
        code = message.source,
      })
    end
  end

  return diagnostics
end

--- Parses a phpstan `--error-format=json` payload into vim.diagnostic items.
--- phpstan reports only errors (no warning tier) and no columns, so items
--- land at column 0.
---@param output string Raw phpstan stdout
---@return vim.Diagnostic[]
local function parse_phpstan(output)
  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= "table" or type(decoded.files) ~= "table" then
    return {}
  end

  local diagnostics = {}
  for _, file in pairs(decoded.files) do
    for _, message in ipairs(file.messages or {}) do
      table.insert(diagnostics, {
        lnum = (message.line or 1) - 1,
        col = 0,
        severity = vim.diagnostic.severity.ERROR,
        message = message.message or "",
        source = "phpstan",
      })
    end
  end

  return diagnostics
end

---@class mars.Linter
---@field name string
---@field cwd string Directory the command is run from
---@field stdin? boolean Feed the buffer's content on stdin
---@field cmd fun(filename: string): string[] Builds the full command
---@field parse fun(output: string): vim.Diagnostic[]

--- Picks PHP's linters for one buffer: phpstan joins in when a phpstan
--- config exists, and phpcs joins in only when Laravel Pint is absent
--- (Pint already enforces style, so phpcs would be redundant).
---@param buf integer
---@param root string
---@return mars.Linter[]
local function php_linters(buf, root)
  local linters = {}

  local has_phpstan_config = vim.fn.filereadable(vim.fs.joinpath(root, "phpstan.neon")) == 1
    or vim.fn.filereadable(vim.fs.joinpath(root, "phpstan.neon.dist")) == 1
    or vim.fn.filereadable(vim.fs.joinpath(root, "phpstan.dist.neon")) == 1
  if has_phpstan_config then
    table.insert(linters, {
      name = "phpstan",
      cwd = root,
      cmd = function(filename)
        return {
          tools.resolve(buf, "phpstan", { root = root }),
          "analyse",
          "--no-progress",
          "--error-format=json",
          filename,
        }
      end,
      parse = parse_phpstan,
    })
  end

  local has_pint = vim.fn.filereadable(vim.fs.joinpath(root, "vendor/bin/pint")) == 1
  if not has_pint then
    table.insert(linters, {
      name = "phpcs",
      cwd = root,
      stdin = true,
      cmd = function(filename)
        return { tools.resolve(buf, "phpcs", { root = root }), "--report=json", "-q", "--stdin-path=" .. filename, "-" }
      end,
      parse = M.parse_phpcs,
    })
  end

  return linters
end

---@type table<string, fun(buf: integer, root: string): mars.Linter[]>
local LINTERS_BY_FT = {
  php = php_linters,
}

---@type table<integer, table<string, vim.Diagnostic[]>>
local diagnostics_by_buf = {}

---@param buf integer
---@param linter_name string
---@param diagnostics vim.Diagnostic[]
local function set_diagnostics(buf, linter_name, diagnostics)
  diagnostics_by_buf[buf] = diagnostics_by_buf[buf] or {}
  diagnostics_by_buf[buf][linter_name] = diagnostics

  local combined = {}
  for _, list in pairs(diagnostics_by_buf[buf]) do
    vim.list_extend(combined, list)
  end
  vim.diagnostic.set(ns, buf, combined)
end

---@param buf integer
---@param linter mars.Linter
---@param filename string
local function run_linter(buf, linter, filename)
  local cmd = linter.cmd(filename)
  local input
  if linter.stdin then
    input = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
  end

  vim.system(cmd, { stdin = input, text = true, cwd = linter.cwd }, function(result)
    -- vim.system callbacks run in a fast-event context where API calls are
    -- illegal, so the whole body has to be deferred, not just the set call.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local diagnostics = linter.parse(result.stdout or "")
      set_diagnostics(buf, linter.name, diagnostics)
    end)
  end)
end

--- Runs every applicable linter for a buffer's filetype. The autocmds below
--- debounce their own calls.
---@param buf? integer Defaults to the current buffer
function M.lint(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modifiable then
    return
  end
  if vim.bo[buf].buftype ~= "" then
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" then
    return
  end

  local factory = LINTERS_BY_FT[vim.bo[buf].filetype]
  if not factory then
    return
  end

  local root = vim.fs.root(buf, { ".git" }) or vim.fn.getcwd()
  local linters = factory(buf, root)
  if #linters == 0 then
    diagnostics_by_buf[buf] = nil
    vim.diagnostic.set(ns, buf, {})
    return
  end

  for _, linter in ipairs(linters) do
    run_linter(buf, linter, filename)
  end
end

local DEBOUNCE_MS = 300

---@type table<integer, uv.uv_timer_t>
local timers = {}

---@param buf integer
local function schedule_lint(buf)
  local timer = timers[buf]
  if not timer then
    timer = assert(vim.uv.new_timer())
    timers[buf] = timer
  end
  timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      M.lint(buf)
    end)
  )
end

---@param buf integer
local function forget_buf(buf)
  diagnostics_by_buf[buf] = nil
  local timer = timers[buf]
  if timer then
    timer:stop()
    timer:close()
    timers[buf] = nil
  end
end

local augroup = vim.api.nvim_create_augroup("mars_lint", { clear = true })

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
  group = augroup,
  desc = "Debounced lint of the buffer",
  callback = function(ev)
    schedule_lint(ev.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = augroup,
  desc = "Drop cached diagnostics/timers for a closed buffer",
  callback = function(ev)
    forget_buf(ev.buf)
  end,
})

vim.api.nvim_create_user_command("Lint", function()
  M.lint(vim.api.nvim_get_current_buf())
end, { desc = "Run linters for the current buffer" })

return M
