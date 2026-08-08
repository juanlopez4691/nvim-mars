# Installation

## Prerequisites

- **Neovim** >= 0.12
- **External tools**: `git`, `ripgrep`, `fd`, `lazygit`, `stylua`, `selene`

Run `:checkhealth mars` after install to verify everything required is on
`PATH`.

Recommended, not required: a [Nerd Font](https://www.nerdfonts.com/font-downloads)
for file-type/git/diagnostic icons. There's no reliable way to detect a
terminal's font from Neovim, so this is a manual opt-in; see
[Customizing](#customizing) below. Mars falls back to plain text/Unicode
symbols otherwise; no font is a hard requirement.

## Dogfooding via `NVIM_APPNAME`

Mars runs side by side with any other Neovim config via `NVIM_APPNAME`, so
there's no need to touch an existing `~/.config/nvim`:

```bash
# Clone this config
git clone https://github.com/joanlopez/nvim-mars.git ~/.config/nvim-mars

# Launch Neovim under the nvim-mars app name
NVIM_APPNAME=nvim-mars nvim
```

Everything Mars needs: config, gitignored local overrides, `vim.pack`
installs, cache and state, lives under the `nvim-mars` app-name directory
tree, entirely separate from your default `~/.config/nvim`. Switching back
to your regular config is just launching `nvim` without the environment
variable.

## First run

On first launch, `vim.pack` installs Mars's plugin exceptions (fzf-lua,
gitsigns.nvim, which-key.nvim, mason.nvim, nvim-treesitter, and so on; see
[Why native-first](/guide/why-native-first) for the full, justified list).
Mason then installs the external tools it manages.

Once that settles:

```vim
:checkhealth mars
:checkhealth
```

`:checkhealth mars` verifies the Neovim version and required external
binaries; the full `:checkhealth` covers LSP, formatter, and linter status
per language.

## Customizing

`lua/mars/local.lua` (copy from `lua/mars/local.lua.example`) is gitignored
and loaded last, after every other module; use it to override any option,
global, keymap, or plugin config without maintaining a diff against a
tracked file. This is also where you opt in to Nerd Font icons:

```lua
-- lua/mars/local.lua
vim.g.have_nerd_font = true
```

## Useful commands

| Command | Description |
| --- | --- |
| `:checkhealth mars` | Verify required tools and Neovim version |
| `:checkhealth` | Run full Neovim health checks |
| `:MarsFormat` | Format the current buffer |
| `:Lint` | Run the linter on the current buffer |
| `:Pack update` | Update plugins (native `vim.pack`) |
| `:source %` | Reload the current config file |

For the language-by-language LSP/formatter/linter matrix, see the
[README's language support table](https://github.com/joanlopez/nvim-mars#language-support).
