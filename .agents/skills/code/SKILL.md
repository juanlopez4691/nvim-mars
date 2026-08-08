---
name: code
user-invocable: false
description: >
  Mars configuration coding conventions. Use when editing Lua files, plugin
  specs, keymaps, or options in this native-first Neovim config. Covers hard
  constraints, the native-vs-plugin decision rule, code patterns, naming, and
  verification. For full details see AGENTS.md in the repository root.
---

# Mars Coding Conventions

## Scope

This skill covers **code changes only**: writing and editing Lua in this
repo. It does NOT cover formatting (see `/format`), linting (see `/lint`),
or commit style (see `/commit`).

## Hard Constraints (NEVER violate)

- Native-first: before adding a plugin, check whether a native Neovim API
  already covers the need, and check the approved-exceptions list in
  AGENTS.md (`## Native-First Philosophy`). Do not add a plugin that
  overlaps an already-approved exception.
- Don't `require` auto-loaded config directories: `lua/mars/core/`,
  `lua/mars/ui/`, `lua/mars/lang/`. `lsp/*.lua` files are auto-loaded by
  Neovim itself, not by Mars's own code.
- Don't create new globals from first-party code. Only `vim` is guaranteed;
  see `.luarc.json`/`.emmyrc.json` for the current authoritative list.
- Don't manually edit `vim.pack`'s lockfile. It is machine-generated.

## Code Patterns

- Plugin specs: `lua/mars/plugins/<name>.lua`, one `vim.pack.add()` call
  plus that plugin's config. Defer loading through `lua/mars/pack.lua` when
  a plugin doesn't need to be available at startup.
- LSP servers: `lsp/<server>.lua`, one file per server, using
  `vim.lsp.config()`/`vim.lsp.enable()`.
- Language modules: `lua/mars/lang/<name>.lua`.
- Init in setup functions, not at require time.

## Verify Code

```text
:source %             # Reload current file
:messages             # Check for errors
:checkhealth mars     # Custom health checks (required binaries, version)
:checkhealth          # Full LSP/formatter/linter diagnostics
```

## Naming

- Locals/fields: `snake_case`.
- Functions: `verb_noun`.
- Files: lowercase, hyphens/underscores.
- Modules: `snake_case`, matching their file name.
