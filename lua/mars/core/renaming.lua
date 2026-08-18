local M = {}

local prepare_rename_method = vim.lsp.protocol.Methods.textDocument_prepareRename

local preview_ns = vim.api.nvim_create_namespace("mars_rename_preview")

--- Every word-boundary occurrence of `word` in `bufnr`, as
--- { line, start_char, end_char } (0-indexed columns, end exclusive).
---@param bufnr integer
---@param word string
---@return table[]
local function find_occurrences(bufnr, word)
  local pattern = string.format([[\<%s\>]], vim.pesc(word))
  local regex = vim.regex(pattern)
  local occurrences = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for i = 0, line_count - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    local s, e = regex:match_line(bufnr, i)
    while s do
      occurrences[#occurrences + 1] = { line = i, start_char = s, end_char = e }
      if e >= #line then
        break
      end
      local rs, re = regex:match_line(bufnr, i, e + 1)
      s, e = rs and (rs + e + 1), re and (re + e + 1)
    end
  end

  return occurrences
end

--- Symbol name from a `textDocument/prepareRename` result, falling back
--- to `<cword>` when the range or placeholder is missing.
---@param result table|nil
---@param bufnr integer
---@return string
local function current_word_from_result(result, bufnr)
  if not result then
    return vim.fn.expand("<cword>")
  end

  if result.placeholder then
    return result.placeholder
  end

  if result.range then
    local start_line = result.range.start.line
    local end_line = result.range["end"].line
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
    if #lines > 0 then
      local line = lines[1]
      local start_col = result.range.start.character
      local end_col = result.range["end"].character
      if #lines == 1 then
        return line:sub(start_col + 1, end_col)
      end
    end
  end

  return vim.fn.expand("<cword>")
end

--- Virtual text showing `new_name` over each `occurrence`; clears prior.
---@param bufnr integer
---@param occurrences table[]
---@param new_name string
local function show_preview(bufnr, occurrences, new_name)
  vim.api.nvim_buf_clear_namespace(bufnr, preview_ns, 0, -1)

  if #new_name == 0 then
    return
  end

  for _, pos in ipairs(occurrences) do
    vim.api.nvim_buf_set_extmark(bufnr, preview_ns, pos.line, pos.start_char, {
      virt_text = { { new_name, "IncSearch" } },
      virt_text_pos = "overlay",
      end_col = pos.end_char,
      priority = 200,
    })
  end
end

--- Incremental live-preview rename: each cmdline keystroke overlays the
--- new text over every occurrence; Enter runs `vim.lsp.buf.rename()`, Esc
--- or an empty input cancels.
function M.rename()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr })[1]
  local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-8")

  vim.lsp.buf_request(bufnr, prepare_rename_method, params, function(err, result)
    if err or not result then
      vim.notify("Cannot rename symbol at cursor", vim.log.levels.WARN)
      return
    end

    local current_word = current_word_from_result(result, bufnr)
    if #current_word == 0 then
      vim.notify("No symbol to rename", vim.log.levels.WARN)
      return
    end

    local occurrences = find_occurrences(bufnr, current_word)
    if #occurrences == 0 then
      vim.lsp.buf.rename()
      return
    end

    local input_group = vim.api.nvim_create_augroup("mars_rename", { clear = true })

    vim.api.nvim_create_autocmd("CmdlineChanged", {
      group = input_group,
      callback = function()
        vim.schedule(function()
          show_preview(bufnr, occurrences, vim.fn.getcmdline())
        end)
      end,
    })

    vim.fn.inputsave()
    local new_name = vim.fn.input("Rename: ", current_word)
    vim.fn.inputrestore()

    vim.schedule(function()
      vim.api.nvim_del_augroup_by_id(input_group)
      vim.api.nvim_buf_clear_namespace(bufnr, preview_ns, 0, -1)

      if #new_name == 0 or new_name == current_word then
        return
      end

      vim.lsp.buf.rename(new_name)
    end)
  end)
end

vim.api.nvim_create_user_command("MarsRename", function()
  M.rename()
end, { desc = "Incremental rename with live preview" })

--- Renames `from` on disk, remaps any window showing it to the new path,
--- then deletes the stale buffer.
---@param from string absolute path
---@param to string absolute path
---@return boolean ok
local function rename_on_disk(from, to)
  vim.fn.mkdir(vim.fs.dirname(to), "p")
  if vim.fn.rename(from, to) ~= 0 then
    vim.notify(("Failed to rename file: %s"):format(from), vim.log.levels.ERROR)
    return false
  end

  local from_buf = vim.fn.bufnr(from)
  if from_buf >= 0 then
    local to_buf = vim.fn.bufadd(to)
    vim.bo[to_buf].buflisted = true
    for _, win in ipairs(vim.fn.win_findbuf(from_buf)) do
      vim.api.nvim_win_call(win, function()
        vim.cmd.buffer(to_buf)
      end)
    end
    vim.api.nvim_buf_delete(from_buf, { force = true })
  end
  return true
end

--- Renames a file with LSP awareness per the `workspace/willRenameFiles`/
--- `didRenameFiles` spec: "will" clients may return a WorkspaceEdit (e.g.
--- updated imports) applied before the rename; "did" clients get a
--- fire-and-forget notification after.
---@param from string absolute path
---@param to string absolute path
local function rename_with_lsp(from, to)
  local changes = { files = { { oldUri = vim.uri_from_fname(from), newUri = vim.uri_from_fname(to) } } }
  local clients = vim.lsp.get_clients()

  for _, client in ipairs(clients) do
    if client:supports_method("workspace/willRenameFiles") then
      local resp = client:request_sync("workspace/willRenameFiles", changes, 1000, 0)
      if resp and resp.result then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    end
  end

  if not rename_on_disk(from, to) then
    return
  end

  for _, client in ipairs(clients) do
    if client:supports_method("workspace/didRenameFiles") then
      client:notify("workspace/didRenameFiles", changes)
    end
  end
end

--- Prompts for a new name for `opts.from` (default: the current buffer's
--- file), then renames it LSP-aware; the file-rename counterpart to
--- M.rename()'s symbol rename.
---@param opts? { from?: string }
function M.rename_file(opts)
  opts = opts or {}
  local from = vim.fn.fnamemodify(opts.from or vim.api.nvim_buf_get_name(0), ":p")
  if from == "" then
    vim.notify("No file to rename", vim.log.levels.WARN)
    return
  end

  local dir = vim.fs.dirname(from)
  local basename = vim.fs.basename(from)

  vim.ui.input({ prompt = "New File Name: ", default = basename, completion = "file" }, function(value)
    if not value or value == "" or value == basename then
      return
    end
    rename_with_lsp(from, vim.fs.joinpath(dir, value))
  end)
end

vim.api.nvim_create_user_command("MarsRenameFile", function()
  M.rename_file()
end, { desc = "Rename the current file with LSP awareness" })

vim.keymap.set("n", "<leader>cR", "<cmd>MarsRenameFile<cr>", { silent = true, desc = "Rename File" })

return M
