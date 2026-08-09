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
      -- Vertical list instead of the default multi-column grid: cap the
      -- popup at one readable-width column, then force exactly one column
      -- by setting layout.width.min above any width that column could
      -- realistically take (which-key clamps it back down to the popup's
      -- own width (see its layout.lua), so this always resolves to
      -- "exactly as wide as the popup", never more than one fits).
      win = {
        width = { min = 40, max = 60 },
        -- which-key's own default (win.lua) is col=0 (flush left); math.huge
        -- mirrors its *own* row=math.huge default trick; Layout.dim clamps
        -- it down to the largest valid position, i.e. flush right instead.
        col = math.huge,
        border = require("mars.ui.borders").style(),
      },
      layout = { width = { min = 999 } },
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
      group("<leader>q", "Session"),
      group("<leader>r", "Replace"),
      group("<leader>s", "Search & replace"),
      group("<leader>t", "Terminal"),
      group("<leader>u", "UI toggles"),
      group("<leader>y", "Yank"),
    })
  end,
})
