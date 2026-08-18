-- which-key.nvim: leader-key hint popup and group labels. No native API
-- reproduces this.

require("mars.pack").add({
  { src = "https://github.com/folke/which-key.nvim" },
})

require("mars.pack").on({
  event = "VimEnter",
  config = function()
    -- The default `icons.keys` renders special keys as Nerd Font glyphs;
    -- fall back to plain text when the user hasn't opted into a Nerd Font.
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
      -- Force a single-column list: layout.width.min (999) sits above any
      -- width the popup could take, and which-key clamps it back down to the
      -- popup's own width, so it resolves to "exactly as wide as the popup".
      win = {
        width = { min = 40, max = 60 },
        -- col=math.huge mirrors which-key's own row=math.huge trick:
        -- Layout.dim clamps it to the largest valid position (flush right).
        col = math.huge,
        border = require("mars.ui.borders").style(),
      },
      layout = { width = { min = 999 } },
    })

    -- Leader-key group labels. Keymaps land later alongside the features
    -- that use them; a group with no mappings yet shows an empty entry,
    -- which is expected here. Registered for normal and visual ("x") mode
    -- alike, so the same label shows whether the leader is pressed from a
    -- selection or not, instead of a bare "+N keymaps".
    ---@param lhs string
    ---@param name string
    ---@return { [1]: string, group: string, mode: string[] }
    local function group(lhs, name)
      local spec = { lhs }
      spec.group = name
      spec.mode = { "n", "x" }
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
      group("<leader>s", "Search"),
      group("<leader>t", "Terminal"),
      group("<leader>v", "Vim"),
      group("<leader>w", "Window"),
      group("<leader>y", "Copy & Paste"),
    })
  end,
})
