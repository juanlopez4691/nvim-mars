-- Native diagnostics config: current-line-only virtual text approximates
-- the inline, powerline-style look of a plugin like tiny-inline-diagnostic
-- without one. Icons are gated behind vim.g.have_nerd_font (see AGENTS.md's
-- Icons section).

local severity = vim.diagnostic.severity

local icons = vim.g.have_nerd_font
    and {
      [severity.ERROR] = "󰅚 ",
      [severity.WARN] = "󰀪 ",
      [severity.INFO] = "󰋽 ",
      [severity.HINT] = "󰌶 ",
    }
  or {
    [severity.ERROR] = "E ",
    [severity.WARN] = "W ",
    [severity.INFO] = "I ",
    [severity.HINT] = "H ",
  }

vim.diagnostic.config({
  underline = true,
  severity_sort = true,
  signs = { text = icons },
  virtual_text = {
    current_line = true,
    spacing = 2,
    source = "if_many",
    prefix = function(diagnostic)
      return icons[diagnostic.severity]
    end,
  },
  float = {
    border = "rounded",
    source = "if_many",
  },
})
