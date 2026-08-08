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
