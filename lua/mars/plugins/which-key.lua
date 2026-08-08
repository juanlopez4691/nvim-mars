-- which-key.nvim: leader-key hint popup and group labels. No native API
-- reproduces this (see AGENTS.md's approved exception list).

require("mars.pack").add({
  { src = "https://github.com/folke/which-key.nvim" },
})

require("mars.pack").on({
  event = "VimEnter",
  config = function()
    -- The default `icons.keys` table renders special keys (Ctrl, CR, Esc,
    -- F1..F12, ...) as Nerd Font glyphs. Fall back to plain text when the
    -- user hasn't opted into a Nerd Font.
    local key_icons
    if not vim.g.have_nerd_font then
      key_icons = {
        Up = "Up ",
        Down = "Down ",
        Left = "Left ",
        Right = "Right ",
        C = "C-",
        M = "M-",
        D = "D-",
        S = "S-",
        CR = "CR ",
        Esc = "Esc ",
        ScrollWheelDown = "ScrollDown ",
        ScrollWheelUp = "ScrollUp ",
        NL = "NL ",
        BS = "BS ",
        Space = "Space ",
        Tab = "Tab ",
        F1 = "F1",
        F2 = "F2",
        F3 = "F3",
        F4 = "F4",
        F5 = "F5",
        F6 = "F6",
        F7 = "F7",
        F8 = "F8",
        F9 = "F9",
        F10 = "F10",
        F11 = "F11",
        F12 = "F12",
      }
    end

    require("which-key").setup({
      icons = { keys = key_icons },
    })

    -- Leader-key group labels. Keymaps land later alongside the features
    -- that use them; which-key shows an empty entry for a group with no
    -- mappings yet, which is expected here.
    ---@param lhs string
    ---@param name string
    ---@return wk.Spec
    local function group(lhs, name)
      local spec = { lhs }
      spec.group = name
      return spec
    end

    require("which-key").add({
      group("<leader>a", "AI"),
      group("<leader>c", "Code"),
      group("<leader>d", "Debug"),
      group("<leader>f", "Find"),
      group("<leader>g", "Git"),
      group("<leader>l", "Laravel"),
      group("<leader>o", "OpenCode"),
      group("<leader>r", "Replace"),
      group("<leader>s", "Search & replace"),
      group("<leader>t", "Terminal"),
      group("<leader>y", "Yank"),
    })
  end,
})
