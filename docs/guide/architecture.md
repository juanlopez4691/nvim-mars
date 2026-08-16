# Architecture overview

This page summarizes how Mars is put together. The repository's own
[ARCHITECTURE.md](https://github.com/joanlopez/nvim-mars/blob/main/ARCHITECTURE.md)
is the canonical, more detailed reference; this page links out to it
rather than duplicating every detail, so the two can't silently drift out
of sync.

## Directory layout

```text
init.lua                 # Entrypoint
lsp/                      # Native LSP server configs (vim.lsp.enable convention)
lua/mars/
├── core/                 # Options, LSP enable, completion, diagnostics, netrw, session, lazygit
├── ui/                   # Statusline, winbar, dashboard, notify, patterns, colorscheme
├── lang/                 # Formatting, linting, snippets, tool resolution, blade/antlers filetypes
├── plugins/               # One file per external plugin (vim.pack.add + config)
├── pack.lua              # Lazy-load wrapper around vim.pack
├── health.lua             # :checkhealth mars
└── local.lua.example     # Template for the gitignored lua/mars/local.lua
```

## How it loads

`init.lua` sets `mapleader`/`maplocalleader`, then auto-loads four
directories in order, `core`, `plugins`, `ui`, `lang`, via a small
`require_dir` helper that scans `'runtimepath'` and requires every module in
alphabetical order. `lua/mars/local.lua` (gitignored, user-specific) is
required last via `pcall`, after everything else, so it can override any
option, global, keymap, or plugin config without producing a tracked diff.

`lsp/*.lua` files are a separate mechanism: Mars never `require()`s them
directly. `lua/mars/core/lsp.lua` scans the runtime path for every
`lsp/*.lua` file, takes each file's basename as a server name, and calls
`vim.lsp.enable()` once for the whole list: dropping a new `lsp/foo.lua`
file in is the entire integration step.

## The `vim.pack` lazy-load wrapper

`vim.pack` (Neovim >= 0.12) has no built-in event/filetype/command-based
lazy-loading of its own, so `lua/mars/pack.lua` adds a thin wrapper:

- **`M.add(specs)`** installs a plugin and makes it `require()`-able
  without running its `plugin/`/`ftdetect/` scripts (`load = false`).
- **`M.on(opts)`** defers a plugin's own `setup()` call until an `event`
  or `ft` trigger fires, at most once.

Not every plugin uses `M.on()` the same way: `fzf-lua` defers to first
keymap press, `blade-nav.nvim` is fully self-initializing via its own
`ftplugin` scripts, `nvim-treesitter` configures eagerly since it doesn't
support lazy-loading upstream. See ARCHITECTURE.md's
[vim.pack lazy-load wrapper section](https://github.com/joanlopez/nvim-mars/blob/main/ARCHITECTURE.md#the-vimpack-lazy-load-wrapper)
for the full per-plugin trigger table.

## Native-vs-plugin decisions, in short

Every plugin in the config is there because it cleared the bar in
[Why native-first](/guide/why-native-first): genuinely singular-purpose and
materially hard to reproduce. Everything else, statusline, winbar,
dashboard, notifications, sessions, diagnostics lists, TODO-comment
highlighting, the colorscheme; is a first-party native module instead.

ARCHITECTURE.md tracks this as two living tables: approved exceptions and
their current implementation status, and declined plugins with the native
module that replaced each: so the record stays accurate as the project
grows rather than becoming stale prose.

## Known gaps

ARCHITECTURE.md is intentionally honest about where the current tree hasn't
caught up to AGENTS.md's target shape yet: for example, `nvim-dap` and
`opencode.nvim` are approved exceptions with reserved keymap namespaces but
no `plugins/*.lua` file yet at the time of writing. See its
[Gaps section](https://github.com/joanlopez/nvim-mars/blob/main/ARCHITECTURE.md#gaps-between-agentsmd-and-the-current-tree)
for the current list.

## Read more

- [ARCHITECTURE.md](https://github.com/joanlopez/nvim-mars/blob/main/ARCHITECTURE.md): full directory-by-directory and module-loading detail.
- [AGENTS.md](https://github.com/joanlopez/nvim-mars/blob/main/AGENTS.md): the native-first rule, conventions, and contributor guidance.
