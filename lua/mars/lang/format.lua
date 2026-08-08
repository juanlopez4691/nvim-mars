-- Native formatting: a BufWritePre hook plus a manual :MarsFormat command.
-- Every formatter is run against a copy of the buffer's content (stdin, or a
-- scratch file for tools that only know how to edit a file in place) so the
-- real file on disk is never touched directly; the result only lands in the
-- buffer, once, after the external command has actually succeeded.

local tools = require("mars.lang.tools")

local M = {}

---@class mars.Formatter
---@field name string Display name used in notifications
---@field bin string Executable name, resolved via mars.lang.tools
---@field args string[] Argument list; "$FILENAME" is substituted per run
---@field stdin? boolean Feed buffer content on stdin and read stdout back;
---  when falsy the buffer is written to a scratch file and "$FILENAME"
---  points at that file instead, whose contents are read back afterwards.
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
---@field mode? "first"|"chain" "first" (default) stops at the first
---  formatter whose condition passes and applies only its output; "chain"
---  runs every applicable formatter in order, feeding each one's output into
---  the next, and only applies the result once the whole chain succeeds.

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

--- Runs a single formatter against `lines`, returning its replacement
--- content. Non-stdin formatters get a scratch copy of the buffer (named
--- after the real file, so extension-sensitive tools like blade-formatter
--- still detect the right language) instead of touching the file being
--- edited.
---@param formatter mars.Formatter
---@param resolved string Resolved executable path
---@param lines string[]
---@param filename string Real buffer filename (used for stdin args/detection)
---@return boolean ok
---@return string[]? lines
---@return string? err
--- Hard ceiling on how long an external formatter may block a save. Passed
--- to SystemObj:wait(), which kills the process and returns promptly if it's
--- exceeded; without this, a wedged daemon (prettierd is a known offender)
--- would hang Neovim on every write with no way out.
local FORMAT_TIMEOUT_MS = 5000

---@param lines string[]
---@return boolean
local function is_blank(lines)
  return vim.trim(table.concat(lines, "\n")) == ""
end

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
  -- SystemObj:wait() kills the process and reports exit code 124 (the same
  -- sentinel GNU `timeout` uses) once the deadline above is hit.
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

  -- A formatter that exits 0 but produces nothing is failing silently, not
  -- succeeding; never let that blank out real content.
  if not is_blank(lines) and is_blank(output_lines) then
    return false, nil, "produced empty output"
  end

  return true, output_lines
end

--- Runs a format spec's formatter list against `lines`. See mars.FormatSpec
--- for "first" vs "chain" semantics. A formatter is only attempted once it
--- both resolves to something executable and its condition (if any) passes.
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
      current = output
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

--- Formats a buffer in place: resolves the applicable formatter(s) for its
--- filetype, runs them, and (only if the buffer wasn't modified while they
--- were running and the result actually differs) replaces its content in a
--- single change, preserving the cursor position.
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
