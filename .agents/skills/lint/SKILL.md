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

Linting/diagnostics only: Selene and LSP. Not formatting (`/format`) or code
changes (`/code`). Don't run `stylua` unless asked.

## Two Distinct "Lints"

- **Repo's own Lua**: Selene (`selene.toml` + `neovim.yml`). Run `selene .`
  before committing Lua changes. Runs in CI on every push/PR.
- **Files edited inside Mars** (PHP, JS/TS, ...): first-party native module
  `lua/mars/lang/lint.lua` plus LSP sources (e.g. ESLint). On demand: `:Lint`.

Verify status: `:checkhealth mars`, `:checkhealth`, `:messages` after reload.

## Lua Diagnostics From The Terminal

`lua-language-server --check <file>` is unreliable here: it reads `.luarc.json`
but not the Neovim runtime library that `lsp/lua_ls.lua` injects via `on_init`.
Without those meta definitions `vim.fn.*`/`vim.uv.*` resolve to `unknown`, so
real findings (e.g. `string?` from `vim.uv.cwd()`) are silently absent and it
reports a clean file. Drive the actual client instead:

```bash
cat > /tmp/mars-diag.lua <<'EOF'
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  vim.wait(5000, function()
    return #vim.lsp.get_clients({ bufnr = buf }) > 0
  end)
  vim.wait(5000, function()
    return #vim.diagnostic.get(buf) > 0
  end)
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    print(("%s:%d %s"):format(vim.api.nvim_buf_get_name(buf), d.lnum + 1, d.message))
  end
end
EOF
NVIM_APPNAME=nvim-mars nvim --headless \
  -u ~/.config/nvim-mars/init.lua -l /tmp/mars-diag.lua
```

`NVIM_APPNAME=nvim-mars` is mandatory: without it the run loads
`~/.config/nvim` and proves nothing about this config.