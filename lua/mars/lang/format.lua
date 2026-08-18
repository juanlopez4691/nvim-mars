-- Native formatting: BufWritePre hook plus a :MarsFormat command. Formatters
-- run against a copy of the buffer (stdin, or a scratch file for tools that
-- edit in place), so the real file is only replaced after the command succeeds.

local tools = require("mars.lang.tools")

local M = {}

---@class mars.Formatter
---@field name string Display name used in notifications
---@field bin string Executable name, resolved via mars.lang.tools
---@field args string[] Argument list; "$FILENAME" is substituted per run
---@field stdin? boolean Feed buffer content on stdin; when falsy, write to a
---  scratch file named after the buffer and read it back after.
---@field condition? fun(root: string): boolean Project-aware gate; a missing
---  condition always passes.

---@type table<string, mars.Formatter>
local FORMATTERS = {
  prettierd = { name = "prettierd", bin = "prettierd", args = { "$FILENAME" }, stdin = true },
  prettier = { name = "prettier", bin = "prettier", args = { "--stdin-filepath", "$FILENAME" }, stdin = true },
  pint = {
    name = "pint",
    bin = "pint",
    args = { "$FILENAME" },
    condition = function(root)
      return vim.fn.filereadable(vim.fs.joinpath(root, "pint.json")) == 1
        or vim.fn.filereadable(vim.fs.joinpath(root, "vendor/bin/pint")) == 1
    end,
  },
  phpcbf = {
    name = "phpcbf",
    bin = "phpcbf",
    args = { "$FILENAME" },
    condition = function(root)
      return vim.fn.filereadable(vim.fs.joinpath(root, "vendor/bin/phpcbf")) == 1
    end,
  },
  php_cs_fixer = { name = "php-cs-fixer", bin = "php-cs-fixer", args = { "fix", "$FILENAME" } },
  isort = { name = "isort", bin = "isort", args = { "$FILENAME" } },
  black = { name = "black", bin = "black", args = { "$FILENAME" } },
  blade_formatter = { name = "blade-formatter", bin = "blade-formatter", args = { "--write", "$FILENAME" } },
}

---@class mars.FormatSpec
---@field formatters mars.Formatter[]
---@field mode? "first"|"chain" "first" (default) stops at the first formatter
---  whose condition passes; "chain" runs every applicable one in order,
---  feeding each output into the next, and applies only once all succeed.

---@type table<string, mars.FormatSpec>
local FORMATTERS_BY_FT = {
  javascript = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  javascriptreact = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  typescript = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  typescriptreact = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  css = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  scss = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  json = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  jsonc = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  yaml = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  html = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  markdown = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  vue = { formatters = { FORMATTERS.prettierd, FORMATTERS.prettier } },
  php = { formatters = { FORMATTERS.pint, FORMATTERS.phpcbf, FORMATTERS.php_cs_fixer } },
  python = { formatters = { FORMATTERS.isort, FORMATTERS.black }, mode = "chain" },
  blade = { formatters = { FORMATTERS.blade_formatter } },
}

--- Ceiling on how long a formatter may block a save; SystemObj:wait() kills
--- the process past this (prettierd is a known offender).
local FORMAT_TIMEOUT_MS = 5000

---@param lines string[]
---@return boolean
local function is_blank(lines)
  return vim.trim(table.concat(lines, "\n")) == ""
end

--- Runs a single formatter against `lines`, returning its replacement
--- content. Non-stdin formatters get a scratch copy named after the real
--- file, so extension-sensitive tools still detect the right language.
---@param formatter mars.Formatter
---@param resolved string
---@param lines string[]
---@param filename string
---@return boolean ok
---@return string[]? lines
---@return string? err
local function run_formatter(formatter, resolved, lines, filename)
  local tmp_dir, tmp_file
  if not formatter.stdin then
    tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    tmp_file = vim.fs.joinpath(tmp_dir, vim.fs.basename(filename))
    vim.fn.writefile(lines, tmp_file)
  end

  local cmd = { resolved }
  for _, arg in ipairs(formatter.args) do
    table.insert(cmd, arg == "$FILENAME" and (tmp_file or filename) or arg)
  end

  local input = formatter.stdin and (table.concat(lines, "\n") .. "\n") or nil
  local result = vim.system(cmd, { stdin = input, text = true }):wait(FORMAT_TIMEOUT_MS)
  -- SystemObj:wait() reports exit code 124 (the GNU timeout sentinel) on timeout.
  local timed_out = result.code == 124 and result.signal == 9

  local output_lines, read_err
  if result.code == 0 then
    if formatter.stdin then
      output_lines = vim.split(result.stdout or "", "\n")
      if output_lines[#output_lines] == "" then
        table.remove(output_lines)
      end
    else
      local ok_read, content = pcall(vim.fn.readfile, tmp_file)
      if ok_read then
        output_lines = content
      else
        read_err = "formatter output missing (file moved or deleted)"
      end
    end
  end

  if tmp_dir then
    pcall(vim.fn.delete, tmp_dir, "rf")
  end

  if result.code ~= 0 then
    local err
    if timed_out then
      err = ("timed out after %dms"):format(FORMAT_TIMEOUT_MS)
    else
      err = result.stderr
      if not err or err == "" then
        err = ("exit code %d"):format(result.code)
      end
    end
    return false, nil, vim.trim(err)
  end

  if read_err then
    return false, nil, read_err
  end

  -- Exit 0 with no output is a silent failure; don't let it blank real content.
  if not is_blank(lines) and is_blank(output_lines) then
    return false, nil, "produced empty output"
  end

  return true, output_lines
end

--- Runs a format spec's formatter list against `lines`. A formatter is only
--- attempted when it resolves to an executable and its condition (if any)
--- passes. See mars.FormatSpec for "first" vs "chain" semantics.
---@param spec mars.FormatSpec
---@param buf integer
---@param root string
---@param lines string[]
---@param filename string
---@return boolean ok
---@return string[]? lines
---@return string? name Name of the last formatter that ran
---@return string? err
local function run_spec(spec, buf, root, lines, filename)
  local current = lines
  local applied
  local ran = false

  for _, formatter in ipairs(spec.formatters) do
    local resolved = tools.resolve(buf, formatter.bin, { root = root })
    local available = resolved ~= formatter.bin or vim.fn.executable(resolved) == 1
    local condition_ok = not formatter.condition or formatter.condition(root)

    if available and condition_ok then
      ran = true
      local ok, output, err = run_formatter(formatter, resolved, current, filename)
      if not ok then
        return false, nil, formatter.name, err
      end
      current = output or {}
      applied = formatter.name
      if spec.mode ~= "chain" then
        break
      end
    end
  end

  if not ran then
    return false, nil, nil, nil
  end

  return true, current, applied, nil
end

--- Format a buffer in place. Skips if it changed mid-run or output is identical.
---@param buf? integer Defaults to the current buffer
function M.format(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modifiable then
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" then
    return
  end

  local spec = FORMATTERS_BY_FT[vim.bo[buf].filetype]
  if not spec then
    return
  end

  local root = vim.fs.root(buf, { ".git" }) or vim.fn.getcwd()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  local ok, new_lines, name, err = run_spec(spec, buf, root, lines, filename)

  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if not ok then
    if err then
      vim.notify(("Mars: %s failed on %s: %s"):format(name, vim.fs.basename(filename), err), vim.log.levels.WARN)
    end
    return
  end

  if vim.api.nvim_buf_get_changedtick(buf) ~= tick then
    vim.notify(("Mars: skipped %s output; buffer changed while formatting"):format(name), vim.log.levels.WARN)
    return
  end

  if vim.deep_equal(lines, new_lines) then
    return
  end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
  vim.fn.winrestview(view)
end

local augroup = vim.api.nvim_create_augroup("mars_format", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  desc = "Format the buffer before it's written",
  callback = function(ev)
    M.format(ev.buf)
  end,
})

vim.api.nvim_create_user_command("MarsFormat", function()
  M.format(vim.api.nvim_get_current_buf())
end, { desc = "Format the current buffer" })

return M
