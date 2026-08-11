---
name: lint
user-invocable: false
description: >
  Mars configuration linting conventions. Use when linting files in this
  native-first Neovim config repository. Covers Selene for this repo's own
  Lua code, and the distinct native linting module used for files edited
  inside Mars. For full details see AGENTS.md in the repository root.
context: fork
---

# Mars Linting Conventions (This Repo)

## Scope

This skill covers **linting/diagnostics only**: checking for errors via
Selene and LSP. It does NOT cover formatting (see `/format`) or code changes
(see `/code`). Do NOT run `stylua` unless explicitly asked.

## Two Distinct Things Called "Linting"

- **This repo's own Lua code**: linted with
  [Selene](https://github.com/Kampfkarren/selene) (`selene.toml` +
  `neovim.yml`). Run `selene .` before committing Lua changes. This runs in
  CI on every push/PR.
- **Files edited inside Mars** (PHP, JS/TS, etc.): diagnostics come from a
  first-party native linting module (`lua/mars/lang/lint.lua`) plus
  LSP-based sources (e.g. ESLint for JS/TS). Run on demand with `:Lint`.

Run `:checkhealth mars` and `:checkhealth` to verify LSP/linter status.
Check `:messages` after reloading for diagnostic errors.

## Reading Lua Diagnostics From The Terminal

`lua-language-server --check <file>` is **not** a substitute for the warnings
shown in the editor: it reads `.luarc.json` but not the Neovim runtime
library, which `lsp/lua_ls.lua` injects from its `on_init` hook. Without
those meta definitions `vim.fn.*` and `vim.uv.*` resolve to `unknown`, so
the real findings: `string?` from `vim.uv.cwd()`, `string|string[]` from
`vim.fn.getline()`: are silently absent, and it reports success on a file
that has warnings.

Drive the actual client instead: a script that opens each file, waits for
`vim.lsp.get_clients({ bufnr = buf })` to be non-empty, waits again for the
server to publish, then prints `vim.diagnostic.get(buf)`.

```bash
NVIM_APPNAME=nvim-mars nvim --headless \
  -u ~/.config/nvim-mars/init.lua -l diag.lua
```

`NVIM_APPNAME=nvim-mars` is mandatory: without it the run loads
`~/.config/nvim` and proves nothing about this config.
