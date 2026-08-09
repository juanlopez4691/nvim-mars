local M = {}

local prepare_rename_method = vim.lsp.protocol.Methods.textDocument_prepareRename

local preview_ns = vim.api.nvim_create_namespace("mars_rename_preview")

--- Finds every word-boundary occurrence of `word` in `bufnr`, returning
--- { line, start_char, end_char } tables (0-indexed columns, end exclusive)
--- suitable for extmark positioning.
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
    local s, e = regex:match_str(line)
    while s do
      occurrences[#occurrences + 1] = { line = i, start_char = s, end_char = e }
      if e >= #line then
        break
      end
      s, e = regex:match_str(line, e + 1)
    end
  end

  return occurrences
end

--- Extracts the symbol name at the cursor from a `textDocument/prepareRename`
--- result, falling back to `<cword>` when the range or placeholder isn't
--- available.
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

--- Placeholder virtual text that shows `new_name` on top of every
--- `occurrence` position. Clears any prior preview first.
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

--- Incremental, live-preview rename via LSP. On each keystroke in the
--- cmdline input, every word-boundary occurrence of the symbol in the
--- buffer is visually replaced by the text typed so far (extmark overlay).
--- Pressing Enter executes `vim.lsp.buf.rename()`; Esc (or an empty input)
--- cancels and clears the preview.
function M.rename()
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params(0)

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

return M
