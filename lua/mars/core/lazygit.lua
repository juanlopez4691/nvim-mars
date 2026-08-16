-- Lazygit in a centered floating terminal. Edits from inside lazygit land in
-- this instance via its `nvim-remote` editor preset, which needs the config
-- override below; nothing in ~/.config/lazygit is touched.

local M = {}

local term = require("mars.term")

---@type mars.term.State
local state = { win = nil, buf = nil, job = nil }

local augroup = vim.api.nvim_create_augroup("mars_lazygit", { clear = true })

--- Cached `lazygit --print-config-dir`: nil until looked up once, then the
--- directory or false. Can't change within a session, so the blocking call
--- runs once instead of on every open().
---@type string|boolean|nil
local lazygit_config_dir = nil

--- Writes (once) a small lazygit config snippet forcing the `nvim-remote`
--- editor preset, layered over the user's own global config when one exists.
---@return string
local function editor_config_arg()
  local override = vim.fs.joinpath(vim.fn.stdpath("cache"), "mars-lazygit-editor.yml")
  vim.fn.writefile({ "os:", '  editPreset: "nvim-remote"' }, override)

  if lazygit_config_dir == nil then
    local config_dir = vim.fn.system({ "lazygit", "--print-config-dir" })
    lazygit_config_dir = vim.v.shell_error == 0 and vim.trim(config_dir) or false
  end

  if lazygit_config_dir then
    local default_config = vim.fs.joinpath(lazygit_config_dir, "config.yml")
    if vim.fn.filereadable(default_config) == 1 then
      return default_config .. "," .. override
    end
  end

  return override
end

--- Opens lazygit in a centered floating window, reusing the existing one if
--- already open. Notifies instead of opening an empty terminal when lazygit
--- isn't installed.
function M.open()
  if term.focus(state) then
    vim.cmd.startinsert()
    return
  end

  if vim.fn.executable("lazygit") == 0 then
    vim.notify("lazygit not found on PATH; install it to use :MarsLazygit", vim.log.levels.ERROR)
    return
  end

  local win = term.open(state, {
    cmd = { "lazygit", "--use-config-file", editor_config_arg() },
    cwd = vim.fs.root(0, ".git") or vim.uv.cwd(),
    win_config = term.float_geometry(),
  })
  if win then
    vim.cmd.startinsert()
  end
end

vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  desc = "Keep the lazygit float centered and sized to the current window",
  callback = function()
    term.recenter(state, term.float_geometry())
  end,
})

vim.api.nvim_create_user_command("MarsLazygit", M.open, { desc = "Open lazygit in a floating window" })

vim.keymap.set("n", "<leader>gg", M.open, { desc = "Open lazygit" })

return M
