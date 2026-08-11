---
name: commit
description: >
  Mars configuration commit conventions. Use when committing changes in this
  native-first Neovim config. Covers Conventional Commits style specific to
  this repository. For full details see AGENTS.md in the repository root.
user-invocable: false
context: fork
---

# Mars Commit Conventions

For commit style, branching, and history rules, see AGENTS.md.

## Commit Command

Always use a plain string literal: no heredocs or subshell expansion:

```bash
git commit -m "type: subject"
```

Heredocs and `$(...)` in this environment cause delta/highlight to embed ANSI
codes into the stored commit message. No `Co-Authored-By` trailers.

## Before Every Commit

Two passes, both required. Do them unprompted; a follow-up asking "can this
be simplified?" or "why are there LSP warnings?" means this was skipped.

1. **Read the diff as a reviewer.** Is it the simplest thing that works? Cut
   redundant helpers, duplicated calls, and checks that can't change the
   outcome. Prefer removing code over adding guards; unrecognized values of
   a `vim.g.mars_*` setting fall back to the default silently rather than
   warning.
2. **Prove it's clean**: `stylua .`, `selene .`, zero LSP diagnostics on
   every file touched (see `/lint`: `lua-language-server --check` does not
   show them), no deprecated APIs, and a clean
   `NVIM_APPNAME=nvim-mars nvim --headless +qa`.

Fixes found this way belong in the commit that introduced the code: amend
while it's still unpushed rather than stacking a cleanup commit on top.
