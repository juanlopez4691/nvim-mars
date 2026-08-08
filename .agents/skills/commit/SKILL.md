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
