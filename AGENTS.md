# AGENTS.md

## Purpose

Repo-specific guidance for agents and humans working on **Mars**, a minimal,
native-first Neovim (>= 0.12) config. Covers reload, format/lint, validation,
code style, and the native-vs-plugin decision rule that defines the project.

## For AI Agents

This file is the authoritative reference. Fast-path rules are also invokable
skills under `.agents/skills/`: `/code`, `/format`, `/lint`, `/commit`.
Prefer the skill when available; fall back to this file.

## Scope and Precedence

- Scope: whole repo unless a deeper AGENTS.md overrides it.
- Precedence: deeper AGENTS.md > this file > user instructions expressing
  intent or preference (e.g. "use tabs").
- Routine commands ("commit this", "fix that") are NOT intent overrides;
  apply commit conventions, formatting, and code style automatically. Don't
  bundle unrelated changes just because they were mentioned together.
- Document working intent here; don't duplicate Neovim's own docs.

## Project Status

Mars is built out incrementally. This file is the spec the finished code
follows: treat it as the target, not just a record of what exists.

## Native-First Philosophy

The defining constraint: read before adding anything.

- **Default to Neovim's native APIs.** `vim.lsp.config`/`vim.lsp.enable`
  (LSP), `vim.lsp.completion` (completion), `vim.snippet` (snippets),
  `vim.o.statusline`/`vim.o.winbar` (UI), `vim.pack` (plugins),
  `:mksession` (sessions), `vim.diagnostic.*` (diagnostics), netrw (file
  browsing), `:grep`/quickfix (search), `jobstart`+`term`/`nvim_open_term`
  (terminals: `lua/mars/helpers/term.lua` is the shared native manager
  powering the generic `<leader>t` shell, lazygit, scooter, and opencode;
  snacks.terminal was considered and declined as a whole-plugin dependency).
- **Add a plugin only when it is genuinely singular-purpose and materially
  hard to reproduce natively**: not merely convenient. Check native
  coverage first; prefer a small first-party module over a new dependency.
- **Approved exception plugins** (do not add an overlapping plugin without
  discussion first):
  - `fzf-lua`: fuzzy picker; no native fuzzy-match UI exists.
  - `gitsigns.nvim`: git gutter signs/staging; nontrivial diff-parsing and
    debounced rendering.
  - `which-key.nvim`: keymap-hint popup; no native equivalent.
  - `mason.nvim`: cross-platform external tool/binary installer.
  - `nvim-treesitter` (main branch): parser install/update only; runtime
    highlighting/folding is native (`vim.treesitter.*`).
  - `nvim-dap` + `nvim-dap-ui` + `nvim-dap-virtual-text` + `mason-nvim-dap`;
    debugging is the "complex, worth a plugin" case.
  - `opencode.nvim`: AI chat/agent integration; the sole AI surface.
  - `adalessa/laravel.nvim`: Laravel-specific pickers/commands (upstream).
  - `blade-nav.nvim`: Blade tag-completion source.
- **Considered and declined** (don't re-propose without a concrete gap):
  - `diffview.nvim`: the lazygit float (`lua/mars/core/lazygit.lua`) plus
    `:diffthis`/gitsigns `<leader>ghd` cover diff review.
  - `gitlineage.nvim`: gitsigns `<leader>ghb`/`<leader>ghB` plus lazygit
    cover blame/history.
  - `trouble.nvim`: `vim.diagnostic.setqflist()`/`setloclist()` populate the
    native lists; see `lua/mars/core/diagnostics.lua`.
  - `todo-comments.nvim` / `mini.hipatterns`: native extmarks in
    `lua/mars/ui/patterns.lua`.
- **No plugin-manager framework, dashboard/explorer/statusline/notifier/theme
  plugin.** Colorscheme is built-in `default`. Statusline, winbar, dashboard,
  notifications, sessions, formatting, and linting are first-party native
  modules (see Code Structure). No AI ghost-text completion; opencode.nvim is
  the sole AI surface.

### Icons

No icon plugin; a Nerd Font is recommended but never required. Fonts can't be
detected from Neovim, so `vim.g.have_nerd_font` (default `false`, set in
`lua/mars/core/options.lua`) is a manual opt-in. Any UI using filetype/git/
diagnostic glyphs (statusline, winbar, dashboard, diagnostics signs, ...)
gates them on that flag and falls back to text/Unicode symbols when unset.

Read the flag **at point of use**, never at module-require time.
`lua/mars/local.lua` (where users set it) loads last, after every
`require_dir` call, so a load-time `local icons = vim.g.have_nerd_font and
{...} or {...}` freezes to the fallback before the user's value exists and
dead-ends the font branch. Same rule for any user-tunable global: resolve at
point of use, don't memoize in an upvalue. To verify icon behavior, set the
flag via `lua/mars/local.lua`, not by presetting the global in the test
harness: the test would pass while real startup doesn't.

## Build, Reload, Health

- No build step; Neovim loads the config automatically.
- Apply changes: `:source %` or restart.
- Health: `:checkhealth mars` (custom module; verifies binaries + Neovim
  version); `:checkhealth` (full LSP/formatter/linter diagnostics);
  `:messages` after reload for warnings/errors.
- Sanity load: `nvim --headless +qa` (doesn't cover lazy-loaded paths); same
  check runs in CI.
- Dogfooding: run standalone via `NVIM_APPNAME=nvim-mars nvim`.

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):
`type: subject`.

- Subject explains WHY: the problem solved or feature added. Not WHAT or
  HOW; the code already shows that.
- Scopes: only `(ai)`, required for agent-steering files (`AGENTS.md`,
  `CLAUDE.md`, `.agents/skills/**`, `.claude/**`). All other commits are
  scopeless. Never append a context suffix (e.g. `(fixes #123)`).
- No body unless it carries "why" the subject can't.
- One logical change per commit. A subject reading "X and Y" must split into
  (at least) two commits.
- `.md` changes use `docs:`; `docs(ai):` when the file is agent-facing.
- `fix:` corrects broken/incorrect behavior. `feat:` adds behavior or
  robustness, including preventing a class of error. Verbs like "avoid",
  "prevent", "guard", "protect" signal `feat:`, not `fix:`.
- Omit context derivable from git blame, the file list, or the repo name.
- Shortest subject that preserves full meaning; clarity beats brevity only
  when something would otherwise be ambiguous.

### Commit Command

Plain string literal: no heredocs or `$(...)` (delta/highlight embeds ANSI
codes into the message). No `Co-Authored-By` trailers.

```bash
git commit -m "type: subject"
```

### Examples

- ❌ `docs: fix markdownlint in README and AGENTS`
  → Two unrelated files; split into two commits.
- ✅ `docs: fix markdownlint errors in README`
  → Single topic, self-contained.
- ❌ `docs: require a self-review pass before committing`
  → Edits AGENTS.md and a skill, so the `(ai)` scope is required.
- ✅ `docs(ai): require a self-review pass before committing`
  → Same subject, correctly scoped.
- ❌ `feat: add lsp config and completion setup`
  → "and" signals two changes; must be split.
- ❌ `fix: pass cwd to vim.fs.root so project root resolves correctly`
  → Explains WHAT (pass cwd) and HOW (via vim.fs.root), not WHY. Also wrong
    type: it prevents a latent bug, so `feat:` applies.
- ✅ `feat: avoid wrong laravel env due to buffer-sensitive root detection`
  → Names the consequence avoided and the root cause; type matches intent.
- ❌ `feat: add native statusline module for this neovim config`
  → "for this neovim config" is obvious from the repo; "module" is redundant
    when the file list shows a new file.
- ✅ `feat: add native statusline`
  → Concise; the diff tells the rest.

## Branching

Non-trivial/risky changes get a dedicated branch:

```bash
git checkout -b <type>/<brief-description>
```

Examples: `feat/native-statusline`, `fix/fzf-lua-symbol-filter`,
`docs/update-readme`. Keep branches to one logical change. Merge via PR or
fast-forward after review and validation.

## Git History

Linear history; avoid merge commits.

- Rebase feature branches onto `main` before merging:

  ```bash
  git checkout feat/my-branch
  git rebase main
  git checkout main
  git merge --ff-only feat/my-branch
  ```

- Never `git merge --no-ff`. Never merge `main` into a feature branch.

## Formatting

Files: Lua, Markdown, JSON, TOML.

- Lua: Stylua (see `stylua.toml`), 2-space indent, width 120. Format all:
  `stylua .`.
- Markdown/JSON/TOML: LSP + editor defaults; no CLI formatter step.
- In Neovim: `:MarsFormat` (native module, on `BufWritePre` or manually).
  Inspect which binary was picked via `:checkhealth mars`.
- Rules: indent 2, max width 120, break long tables/signatures, no trailing
  whitespace, final newline.

## Linting

Two unrelated things share the name: keep them distinct:

- **This repo's own Lua** is linted with
  [Selene](https://github.com/Kampfkarren/selene) (`selene.toml` +
  `neovim.yml`). Run `selene .` before submitting Lua changes; runs in CI.
- **Files edited inside Mars** (PHP, JS/TS, ...) get diagnostics from the
  first-party module `lua/mars/lang/lint.lua` (replaces nvim-lint) plus LSP
  sources (e.g. ESLint). Triggers `BufWritePost`/`BufReadPost`/`InsertLeave`;
  run on demand with `:Lint`.

## Validation

- No test suite. CI runs `stylua --check`, `selene .`, and a headless
  `nvim --headless +qa` boot test on every push/PR.
- Interactive: `:source %` or restart; clean `:messages` and
  `:checkhealth mars`.
- Before committing: read your diff and leave it clean: no LSP diagnostics
  on touched files, no deprecated APIs, no format/lint findings, no code a
  second pass would delete as redundant. Fold fixes into the commit they
  belong to. See `/commit` (checklist) and `/lint` (reading diagnostics).

## Code Structure and Imports

- Directory layout:
  - `init.lua`: entrypoint.
  - `lsp/*.lua`: native LSP server configs, auto-loaded by
    `vim.lsp.enable()` (Neovim >= 0.11 convention). One file per server.
    Two of them share the `php` filetype: `intelephense.lua` (WordPress) and
    `phpantom.lua` (everything else). They stay apart by gating `root_dir`
    on `lua/mars/helpers/php_project.lua`, so exactly one attaches per
    buffer; keep that gate intact when touching either file.
  - `lua/mars/core/`: options, keymaps, autocmds. Zero plugin dependencies.
  - `lua/mars/ui/`: statusline, winbar, dashboard, notify. Zero plugin
    dependencies.
  - `lua/mars/lang/`: per-language modules (php.lua, laravel.lua, blade.lua,
    twig.lua, antlers.lua, ts.lua, format.lua, lint.lua).
  - `lua/mars/plugins/`: one file per external plugin: `vim.pack.add()` call
    plus that plugin's config.
  - `lua/mars/helpers/`: shared on-demand helpers (debounce, color, term,
    text, php_project). Not auto-loaded; required explicitly by whichever
    module needs them.
  - `lua/mars/pack.lua`: the lazy-load wrapper around `vim.pack`.
  - `lua/mars/local.lua`: gitignored, user-specific overrides. Not part of
    the repo; see `lua/mars/local.lua.example`.
- Do not manually `require` files under `lua/mars/core/`, `lua/mars/ui/`, or
  `lua/mars/lang/`: they are auto-loaded (see `init.lua`'s `require_dir`
  helper). `lsp/*.lua` are loaded by Neovim itself, not by Mars's own code.
- User-specific customization (e.g. `vim.g.have_nerd_font`) belongs in
  `lua/mars/local.lua` (copy `lua/mars/local.lua.example`), not in a tracked
  file: it loads last and can override any option/global/keymap/plugin
  config without a tracked diff.
- Plugin specs live in `lua/mars/plugins/*.lua`. Defer loading through
  `lua/mars/pack.lua`'s wrapper when a plugin isn't needed at startup.
- Keep modules light on side effects; initialize in setup functions where
  possible, not at require time.

## Types and Documentation

- EmmyLua annotations on public functions and module APIs:

  ```lua
  --- Brief description
  ---@param path string
  ---@return boolean
  local function file_exists(path) ... end
  ```

- Module-level doc comments for helpers and plugin specs: intent,
  assumptions, notable side effects.

## Naming Conventions

- Locals/fields: `snake_case`. Modules: `snake_case`, matching the file name.
- Files: lowercase, hyphens/underscores. Functions: `verb_noun` (e.g.
  `file_exists`).
- Globals: only `vim` is guaranteed. New globals only when a dependency sets
  one itself (e.g. `_G.Laravel`); never from first-party code. Authoritative
  list: `.luarc.json`/`.emmyrc.json`; keep them in sync when a new global is
  genuinely required.

## Error Handling and Logging

- `pcall` or guard risky calls (e.g. binaries).
- Fail fast on hard misconfigurations; fall back gracefully for optional
  tools.
- Notify via `vim.notify`/`vim.notify_once` with `vim.log.levels`.
- `vim.schedule` for notifications from callbacks or async contexts.
- Prefer diagnostics and `vim.notify` over stdout/stderr.
- Don't validate `vim.g.mars_*` globals: an unrecognized value silently falls
  back to the documented default: no warning, no allowed-values check. The
  only reader of `lua/mars/local.lua` is its author, and a setting that
  visibly does nothing is its own error message.

## Plugin and Config Patterns

- Autocmds: `vim.api.nvim_create_autocmd` in `lua/mars/core/autocmds/`;
  idempotent, lightweight.
- Keymaps: `vim.keymap.set` in `lua/mars/core/keymaps/`.
- Options: `lua/mars/core/options.lua`.
- LSP servers: `lsp/*.lua`, one per server, using
  `vim.lsp.config()`/`vim.lsp.enable()`. No nvim-lspconfig runtime
  dependency: copy the relevant server config data from its source when
  bootstrapping a new server, then vendor it here.
- Treesitter/Mason: `lua/mars/plugins/treesitter.lua`, `mason.lua`.
- Formatting: `lua/mars/lang/format.lua`; `BufWritePre` + `:MarsFormat`.
- Linting: `lua/mars/lang/lint.lua`; `:Lint`.
- Plugin manager: `vim.pack.add()` calls in `lua/mars/plugins/*.lua`; never
  edit the generated lockfile by hand.

## Repo Notes and File Map

- Stylua: `stylua.toml` (2-space indent, width 120).
- Selene: `selene.toml` + `neovim.yml`.
- LuaLS/EmmyLua globals: `.luarc.json`, `.emmyrc.json`.
- Health checks: `lua/mars/health.lua` (`:checkhealth mars`).
- Formatting config: `lua/mars/lang/format.lua`. Linting config:
  `lua/mars/lang/lint.lua`.
- LSP setup: `lsp/*.lua`.
- Project skills: `.agents/skills/{code,format,lint,commit}`.

## Do and Do Not

- Do: run `stylua .` and `selene .` before submitting changes.
- Do: use Neovim APIs (`vim.*`) instead of shelling out or reaching for a
  plugin when possible.
- Do not: add a plugin that overlaps an approved exception, or a plugin at
  all when a native API covers the need.
- Do not: manually require auto-loaded config directories.
- Do not: introduce new globals from first-party code; keep modules explicit.
- Do not: manually edit `vim.pack`'s lockfile; it's machine-generated.

## Useful Commands (Cheat Sheet)

- Format Lua: `stylua .`
- Lint Lua: `selene .`
- In Neovim: `:source %`, `:checkhealth mars`, `:MarsFormat`, `:Lint`,
  `:messages`

## Resources

- [INSPIRATION.md](INSPIRATION.md): reference repos and docs to consult
  before implementing a milestone.
- [Neovim user docs](https://neovim.io/doc/user/)
- [Neovim LSP docs](https://neovim.io/doc/user/lsp.html)
- [vim.pack docs](https://neovim.io/doc/user/pack.html)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)
- [which-key.nvim](https://github.com/folke/which-key.nvim)
- [mason.nvim](https://github.com/mason-org/mason.nvim)
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [opencode.nvim](https://github.com/NickvanDyke/opencode.nvim)
- [adalessa/laravel.nvim](https://github.com/adalessa/laravel.nvim)