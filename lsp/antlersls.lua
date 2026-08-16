-- Vendored from nvim-lspconfig's lsp/antlersls.lua, with root resolution
-- replaced by an actual Statamic-project check: upstream's filetypes include
-- plain "html" and its ".git" root_marker would attach HTML buffers in
-- nearly any git repo. Instead, root_dir walks to the nearest composer.json
-- and only calls on_dir when that project looks like Statamic: its
-- require/require-dev lists a statamic/* package, or a content/ directory
-- sits beside it. A missing/unparsable composer.json is treated as "not
-- Statamic", never as an error.

--- Decode composer.json at `path`, if present and valid JSON.
---@param path string
---@return table?
local function read_composer_json(path)
  local ok_read, contents = pcall(vim.fn.readfile, path)
  if not ok_read or not contents then
    return nil
  end

  local ok_decode, decoded = pcall(vim.json.decode, table.concat(contents, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    return nil
  end

  return decoded
end

--- Whether a composer.json's require/require-dev declares any statamic/* package.
---@param composer table
---@return boolean
local function requires_statamic(composer)
  for _, key in ipairs({ "require", "require-dev" }) do
    local deps = composer[key]
    if type(deps) == "table" then
      for package_name in pairs(deps) do
        if type(package_name) == "string" and package_name:match("^statamic/") then
          return true
        end
      end
    end
  end
  return false
end

---@type vim.lsp.Config
return {
  cmd = { "antlersls", "--stdio" },
  filetypes = { "html", "antlers" },
  root_dir = function(bufnr, on_dir)
    local composer_dir = vim.fs.root(bufnr, { "composer.json" })
    if not composer_dir then
      return
    end

    local composer = read_composer_json(vim.fs.joinpath(composer_dir, "composer.json"))
    local is_statamic = (composer ~= nil and requires_statamic(composer))
      or vim.fn.isdirectory(vim.fs.joinpath(composer_dir, "content")) == 1

    if is_statamic then
      on_dir(composer_dir)
    end
  end,
}
