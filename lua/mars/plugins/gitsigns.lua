-- gitsigns.nvim: git gutter hunk signs, staging, and blame. Nontrivial
-- diff-parsing and debounced rendering (see AGENTS.md's approved exception
-- list).

require("mars.pack").add({
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
})

require("mars.pack").on({
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("gitsigns").setup({
      preview_config = { border = require("mars.ui.borders").style() },
    })

    local hunk_group = { "<leader>gh" }
    hunk_group.group = "Hunk"
    require("which-key").add({ hunk_group })
  end,
})

--- Jump to the next/previous hunk. Defers to the native diff-mode jump
--- (`]c`/`[c`) inside a diff window, where those already do the right
--- thing; otherwise wraps around at the first/last hunk per 'wrapscan'.
---@param direction "next"|"prev"
---@return fun()
local function nav_hunk(direction)
  return function()
    if vim.wo.diff then
      local native_jump = { direction == "next" and "]c" or "[c" }
      native_jump.bang = true
      vim.cmd.normal(native_jump)
    else
      require("gitsigns").nav_hunk(direction)
    end
  end
end

vim.keymap.set("n", "]h", nav_hunk("next"), { silent = true, desc = "Next Hunk" })
vim.keymap.set("n", "[h", nav_hunk("prev"), { silent = true, desc = "Previous Hunk" })

vim.keymap.set("n", "<leader>uG", function()
  vim.wo.signcolumn = vim.wo.signcolumn == "yes" and "no" or "yes"
end, { silent = true, desc = "Toggle signcolumn" })

-- Toggles: staging an already-staged hunk unstages it, so there's no
-- separate undo mapping.
vim.keymap.set("n", "<leader>ghs", function()
  require("gitsigns").stage_hunk()
end, { silent = true, desc = "Stage/Unstage Hunk" })

vim.keymap.set("x", "<leader>ghs", function()
  require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { silent = true, desc = "Stage/Unstage Hunk" })

vim.keymap.set("n", "<leader>ghr", function()
  require("gitsigns").reset_hunk()
end, { silent = true, desc = "Reset Hunk" })

vim.keymap.set("x", "<leader>ghr", function()
  require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
end, { silent = true, desc = "Reset Hunk" })

vim.keymap.set("n", "<leader>ghS", function()
  require("gitsigns").stage_buffer()
end, { silent = true, desc = "Stage Buffer" })

vim.keymap.set("n", "<leader>ghR", function()
  require("gitsigns").reset_buffer()
end, { silent = true, desc = "Reset Buffer" })

vim.keymap.set("n", "<leader>ghp", function()
  require("gitsigns").preview_hunk()
end, { silent = true, desc = "Preview Hunk" })

vim.keymap.set("n", "<leader>ghb", function()
  require("gitsigns").blame_line({ full = true })
end, { silent = true, desc = "Blame Line" })

vim.keymap.set("n", "<leader>ghB", function()
  require("gitsigns").toggle_current_line_blame()
end, { silent = true, desc = "Toggle Line Blame" })

vim.keymap.set("n", "<leader>ghd", function()
  require("gitsigns").diffthis()
end, { silent = true, desc = "Diff This" })
