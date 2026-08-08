# Why native-first

Most popular Neovim configurations and "distributions" are plugin-heavy:
a plugin for the statusline, a plugin for the dashboard, a plugin for
notifications, a plugin manager on top of all of it. That was a reasonable
trade-off when Neovim's own APIs didn't cover the gap: it's a much weaker
one now that they do.

Neovim 0.11+ ships native LSP configuration and activation
(`vim.lsp.config`/`vim.lsp.enable`), LSP-driven completion
(`vim.lsp.completion`), and native snippets (`vim.snippet`). Neovim 0.12
adds a native plugin manager (`vim.pack`). Between those, most of what a
"distribution" exists to provide is now built in.

## The rule

> Default to Neovim's native APIs. Only add a plugin when it is genuinely
> singular-purpose and materially hard to reproduce natively: not merely
> convenient.

Concretely, before adding a plugin dependency, Mars checks whether a native
API already covers the need:

| Concern | Native API |
| --- | --- |
| LSP | `vim.lsp.config` / `vim.lsp.enable` |
| Completion | `vim.lsp.completion` |
| Snippets | `vim.snippet` |
| Plugin management | `vim.pack` |
| Statusline / winbar | `vim.o.statusline` / `vim.o.winbar` |
| Sessions | `:mksession` |
| Diagnostics | `vim.diagnostic.*` |
| File browsing | netrw |
| Search backend | `:grep` / quickfix |

## The exceptions, and why each one earned its place

A short, explicit list; every plugin in Mars is on it, and adding a new one
that overlaps an existing exception means discussing it first, not just
opening a PR:

- **`fzf-lua`**: fuzzy picker; no native fuzzy-match UI exists.
- **`gitsigns.nvim`**: git gutter signs and staging; nontrivial
  diff-parsing and debounced rendering.
- **`which-key.nvim`**: keymap-hint popup; no native equivalent.
- **`mason.nvim`**: cross-platform external tool/binary installer.
- **`nvim-treesitter`** (main branch): parser install/update only; runtime
  highlighting and folding stay native (`vim.treesitter.*`).
- **`nvim-dap` stack**: debugging is explicitly the "complex, worth a
  plugin" case.
- **`opencode.nvim`**: AI chat/agent integration, the sole AI surface (no
  ghost-text completion, no Copilot).
- **`adalessa/laravel.nvim`** and **`blade-nav.nvim`**: Laravel- and
  Blade-specific tooling with no native or trivially-reproducible
  equivalent.

## What got declined, and what replaced it

Just as telling as the exceptions is what Mars considered and turned down,
because a native module already did the job:

| Plugin considered | Replaced by |
| --- | --- |
| `diffview.nvim` | A floating lazygit integration plus `:diffthis` and gitsigns' hunk diff |
| `gitlineage.nvim` | gitsigns' blame commands plus lazygit |
| `trouble.nvim` | `vim.diagnostic.setqflist()` / `setloclist()` into the native quickfix/location list |
| `todo-comments.nvim` / `mini.hipatterns` | Extmark-based highlighting, first-party |

There is also no plugin manager framework beyond `vim.pack` itself, no
dashboard/explorer/statusline/notifier toolkit plugin, and no theme plugin;
the colorscheme is Neovim's built-in `default`.

For the full, current rule and exception list; including anything added
since this page was written: see
[AGENTS.md § Native-First Philosophy](https://github.com/joanlopez/nvim-mars/blob/main/AGENTS.md#native-first-philosophy)
in the repository, which is the source of truth this page summarizes.
