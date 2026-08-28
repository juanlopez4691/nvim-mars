# 🔴 Mars

A minimal, native-first Neovim (>= 0.12) configuration, tailored for PHP,
Laravel, and web development; built on as few plugins as modern Neovim's
native APIs allow.

In Catalonia, we have a proverb: "Qui no té feina, el gat pentina", which
translates to "Those who have no work, brush the cat". This means that when
someone is idle or has nothing to do, they may engage in trivial or
unnecessary tasks, similar to the idea of "idle hands are the devil's
workshop."

I guess sometimes Neovim is like my cat to brush.

## Why Mars

Modern Neovim (0.11+) ships native LSP configuration, LSP-driven completion,
snippets, folding, and a plugin manager (`vim.pack`, 0.12+) that make most of
a typical "distribution" unnecessary. Mars leans on those native APIs as far
as they reasonably go, and only reaches for a plugin when something is
genuinely singular-purpose and hard to reproduce (a fuzzy picker, git gutter
signs, a debugger UI). See [AGENTS.md](AGENTS.md#native-first-philosophy) for
the exact rule and the current list of approved exceptions.

Guiding principles: rely on native APIs, use the fewest plugins possible,
prioritize boot/runtime speed, keep the code modular and pragmatic, enforce
Lua formatting and linting at all times, and document everything well enough
for both humans and AI coding agents to contribute confidently.

## Prerequisites

- **Neovim** >= 0.12
- **External tools**: `git`, `ripgrep`, `fd`, `lazygit`, `stylua`, `selene`
- Run `:checkhealth mars` after install to verify everything required is on
  `PATH`.

Recommended, not required: a [Nerd Font](https://www.nerdfonts.com/font-downloads)
(any of them) for file-type/git/diagnostic icons. There's no reliable way to
detect a terminal's font from Neovim, so this is a manual opt-in: copy
`lua/mars/local.lua.example` to `lua/mars/local.lua` (gitignored) and set
`vim.g.have_nerd_font = true` there: no need to edit a tracked file. Mars
falls back to plain text/Unicode symbols otherwise: no font is a hard
requirement.

## Customizing

`lua/mars/local.lua` (copy from `lua/mars/local.lua.example`) is gitignored
and loaded last, after everything else; use it to override any option,
global, keymap, or plugin config without maintaining a diff against a
tracked file.

## Installation

Mars runs side by side with any other Neovim config via `NVIM_APPNAME`, so
there's no need to touch an existing `~/.config/nvim`.

```bash
# Clone this config
git clone https://github.com/joanlopez/nvim-mars.git ~/.config/nvim-mars

# Launch Neovim under the nvim-mars app name
NVIM_APPNAME=nvim-mars nvim
```

## Language Support

| Language              | LSP           | Formatter        | Linter          |
| ---------------------- | --------------- | ------------------ | ----------------- |
| PHP                   | Intelephense  | Pint, PHPCBF      | PHPStan, PHPCS  |
| Blade                 | blade-nav     | blade-formatter   | —               |
| Twig                  | Twiggy LSP    | —                 | —               |
| JavaScript/TypeScript | vtsls         | Prettierd         | ESLint          |
| Lua                   | LuaLS         | Stylua            | Selene          |
| Tailwind CSS          | Tailwind LSP  | —                 | —               |
| Docker                | Docker LSP    | —                 | —               |
| JSON                  | JSON LSP      | —                 | —               |
| Markdown              | Marksman      | —                 | —               |
| TOML                  | Taplo         | —                 | —               |

## Keymap Namespaces

| Prefix        | Purpose               |
| --------------- | ------------------------ |
| `<leader>a`   | AI (opencode)         |
| `<leader>c`   | Code (lint, symbols)  |
| `<leader>d`   | Debug (DAP)           |
| `<leader>f`   | Find / Pickers        |
| `<leader>g`   | Git                   |
| `<leader>l`   | Laravel               |
| `<leader>o`   | OpenCode (AI chat)    |
| `<leader>q`   | Session               |
| `<leader>r`   | Replace               |
| `<leader>s`   | Search                |
| `<leader>t`   | Terminal              |
| `<leader>y`   | Yank / Paste          |

## Project Structure

```text
init.lua                # Entrypoint
lsp/                     # Native LSP server configs (vim.lsp.enable convention)
lua/mars/
├── core/                # Options, keymaps, autocmds; zero plugin dependencies
├── ui/                  # Statusline, winbar, dashboard, notify; zero plugin dependencies
├── lang/                # Per-language modules (php, laravel, blade, twig, format, lint, ...)
├── plugins/              # One file per external plugin (vim.pack.add + config)
├── helpers/             # Shared on-demand helpers (debounce, color, term, text)
├── pack.lua             # Lazy-load wrapper around vim.pack
└── health.lua            # :checkhealth mars
```

## Contributing

See [AGENTS.md](AGENTS.md) for detailed conventions, the native-first
decision rule, formatting/linting setup, and agent-specific guidelines.
Project-local skills are available under `.agents/skills/`.

## Useful Commands

| Command          | Description                          |
| ------------------ | --------------------------------------- |
| `:checkhealth mars` | Verify required tools and Neovim version |
| `:checkhealth`    | Run full Neovim health checks         |
| `:MarsFormat`     | Format the current buffer             |
| `:Lint`           | Run linter on the current buffer      |
| `:PackUpdate`     | Update plugins (native vim.pack)      |
| `:source %`       | Reload current config file            |
