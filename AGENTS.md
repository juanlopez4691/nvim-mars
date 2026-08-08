# AGENTS.md: Guidelines for Agentic Work in This Neovim Configuration

## Purpose

Practical, repo-specific guidance for agents and human contributors working on
**Mars**, a minimal, native-first Neovim (>= 0.12) configuration. Covers
reload, format/lint, validation, local code style, and, most importantly,
the native-vs-plugin decision rule that defines this project.

## For AI Agents

This file is the comprehensive reference. Critical rules are also available
as invokable skills under `.agents/skills/`: `/code`, `/format`, `/lint`,
`/commit`. Agents should prefer the specific skill when available; fall back
to this file.

## Scope and Precedence

- Scope: Entire repository unless a deeper AGENTS.md overrides it.
- Precedence:
  1. Deeper AGENTS.md files
  2. This file
  3. Direct user instructions that express **intent or preference**
     (e.g., "use tabs instead of spaces")
- Note: routine commands ("commit this", "fix that") do NOT constitute intent
  overrides. Apply commit conventions, formatting, and code style
  automatically. Do not bundle unrelated changes because the user mentioned
  them together.
- Intent: Clarify how to work here without duplicating Neovim's own docs.

## Project Status

Mars is being built out incrementally. This file describes the conventions
the finished code follows: treat it as the spec to build toward, not just a
description of what already exists.

## Native-First Philosophy

This is the defining constraint of the project: read it before adding
anything.

- **Default to Neovim's native APIs.** `vim.lsp.config`/`vim.lsp.enable` for
  LSP, `vim.lsp.completion` for completion, `vim.snippet` for snippets,
  `vim.o.statusline`/`vim.o.winbar` for UI, `vim.pack` for plugin management,
  `:mksession` for sessions, `vim.diagnostic.*` for diagnostics, netrw for
  file browsing, `:grep`/quickfix for search backends.
- **Only add a plugin when it is genuinely singular-purpose and materially
  hard to reproduce natively.** Not "convenient": hard to reproduce. Before
  adding a new plugin dependency, check whether a native API already covers
  the need (see the areas listed above) and prefer writing a small first-party
  module over a new dependency.
- **Currently-approved exception plugins** (do not add another plugin that
  overlaps these without discussing it first):
  - `fzf-lua`: fuzzy picker; no native fuzzy-match UI exists.
  - `gitsigns.nvim`: git gutter signs/staging; nontrivial diff-parsing and
    debounced rendering.
  - `which-key.nvim`: keymap-hint popup; no native equivalent.
  - `mason.nvim`: cross-platform external tool/binary installer.
  - `nvim-treesitter` (main branch): parser install/update only; runtime
    highlighting/folding is native (`vim.treesitter.*`).
  - `nvim-dap` + `nvim-dap-ui` + `nvim-dap-virtual-text` + `mason-nvim-dap`;
    debugging is explicitly the "complex, worth a plugin" case.
  - `opencode.nvim`: AI chat/agent integration; the sole AI surface (no
    Copilot).
  - `adalessa/laravel.nvim`: Laravel-specific pickers/commands (upstream,
    not a local fork).
  - `blade-nav.nvim`: Blade tag-completion source.
- **No plugin manager framework, no dashboard/explorer/statusline/notifier
  toolkit plugin, no theme plugin.** The colorscheme is Neovim's built-in
  `default` for now. The statusline, winbar, dashboard, notifications,
  sessions, formatting, and linting are all first-party native modules;
  see the Code Structure section below. There is no AI ghost-text
  completion (e.g. Copilot); opencode.nvim is the sole AI surface.

### Icons

No icon plugin (no mini.icons/nvim-web-devicons): a Nerd Font is
recommended but never required. There's no reliable way to detect a
terminal's font from Neovim, so `vim.g.have_nerd_font` (default `false`,
set in `lua/mars/core/options.lua`, same pattern as kickstart.nvim) is a
manual opt-in the user flips if they have one installed. Any UI code that
wants file-type/git/diagnostic glyphs (statusline, winbar, dashboard,
diagnostics signs, ...) must gate them behind that flag and fall back to
plain text/Unicode symbols when it's unset.

## Build, Reload, and Health

- Build: No manual build; Neovim loads config automatically.
- Apply changes: `:source %` (current buffer) or restart Neovim.
- Health checks:
  - `:checkhealth mars` (custom health module: verifies required external
    binaries and Neovim version)
  - `:checkhealth` (full LSP/formatter/linter diagnostics)
  - `:messages` after reload to catch warnings/errors
- Headless quick load (sanity): `nvim --headless +qa` (does not cover
  lazy-loaded paths). The same check runs in CI.
- Dogfooding: run this config standalone via `NVIM_APPNAME=nvim-mars nvim`,
  independent of any other Neovim config on the same machine.

## Commit Conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):
`type: subject`.

- Commit subjects should explain WHY the change is made: what problem it
  solves or what feature it adds. Do NOT explain WHAT or HOW; the code
  already does that.
- No scope or context suffix (e.g., no `(fixes #123)` or issue references)
  appended to the subject.
- No commit body unless absolutely necessary to explain the "why." Prefer a
  self-contained subject that makes the body redundant.
- One logical change per commit. Never mix unrelated topics. A commit
  subject that reads "do X and Y" must be split into (at least) two commits.
- Changes to `.md` files (README, AGENTS.md, skills) must use `docs:` type.
- Use `fix:` when correcting something already broken or behaving
  incorrectly. Use `feat:` when adding protection, robustness, or new
  behaviour: including proactively preventing a class of error. Verbs like
  "avoid", "prevent", "guard", "protect" signal `feat:`, not `fix:`.
- Omit context the reader can derive from git blame, the file list, or the
  repo name. If it goes without saying, leave it out.
- Prefer the shortest subject that preserves full meaning. Drop qualifiers,
  redundant context, and implementation detail. Concise beats verbose;
  clarity beats brevity only when something would otherwise be ambiguous.

### Commit Command

Always use a plain string literal: no heredocs or subshell expansion:

```bash
git commit -m "type: subject"
```

Heredocs and `$(...)` in this environment cause delta/highlight to embed ANSI
codes into the stored commit message. No `Co-Authored-By` trailers.

### Examples

- ❌ `docs: fix markdownlint in README and AGENTS`
  → Two unrelated files; split into two commits.
- ✅ `docs: fix markdownlint errors in README`
  → Single topic, self-contained.
- ❌ `feat: add lsp config and completion setup`
  → "and" signals two changes; must be split.
- ❌ `fix: pass cwd to vim.fs.root so project root resolves correctly`
  → Explains WHAT (pass cwd) and HOW (via vim.fs.root), not WHY. Also wrong
    type: the change prevents a latent bug, so `feat:` applies.
- ✅ `feat: avoid wrong laravel env due to buffer-sensitive root detection`
  → Names the consequence avoided and the root cause; type matches intent.
- ❌ `feat: add native statusline module for this neovim config`
  → "for this neovim config" is obvious from the repo; "module" is
    redundant when the file list already shows a new file was added.
- ✅ `feat: add native statusline`
  → Concise; the diff tells the rest.

## Branching

For non-trivial or risky changes, create a dedicated branch:

```bash
git checkout -b <type>/<brief-description>
```

Examples: `feat/native-statusline`, `fix/fzf-lua-symbol-filter`,
`docs/update-readme`.

Keep branches focused on a single logical change. Merge via PR or
fast-forward after review and validation.

## Git History

Maintain a **linear history**. Avoid merge commits.

- Rebase feature branches onto `main` before merging:

  ```bash
  git checkout feat/my-branch
  git rebase main
  git checkout main
  git merge --ff-only feat/my-branch
  ```

- Never use `git merge --no-ff`.
- Never merge `main` into a feature branch; always rebase.

## Formatting

This repository contains **Lua, Markdown, JSON, and TOML** files.

- **Lua** via Stylua (see `stylua.toml`): 2-space indent, width 120.
  - Format all Lua: `stylua .`
- **Markdown, JSON, TOML**: handled by LSP and editor defaults. No manual
  CLI formatter steps required.
- In Neovim, format the current buffer with the native formatting module
  (`lua/mars/lang/format.lua`, triggered on `BufWritePre`, or manually):

  ```vim
  :MarsFormat
  ```

- Inspect formatter resolution (which binary was picked and why) via
  `:checkhealth mars`.

### Formatting Rules (Project-wide)

- Indentation: 2 spaces; max width: 120. (Enforced by `stylua.toml`.)
- Keep tables and function signatures readable; break long lines.
- No trailing whitespace; ensure a final newline.

## Linting

Two separate things are both called "linting" here: keep them distinct:

- **This repo's own Lua code** is linted with
  [Selene](https://github.com/Kampfkarren/selene) (see `selene.toml` and
  `neovim.yml`). Run `selene .` before submitting Lua changes. This runs in
  CI on every push/PR.
- **Files edited inside Mars** (PHP, JS/TS, etc.) get diagnostics from a
  first-party native linting module (`lua/mars/lang/lint.lua`, replacing
  nvim-lint), plus LSP-based diagnostics (e.g. ESLint) where applicable.
  Triggers on `BufWritePost`/`BufReadPost`/`InsertLeave`; run on demand with
  `:Lint`.

## Validation

- No formal automated test suite. Validation is a mix of CI and interactive
  checks:
  - CI: `stylua --check`, `selene .`, and a headless `nvim --headless +qa`
    boot smoke test on every push/PR.
  - Interactively: `:source %` or restart; confirm no errors in `:messages`
    and `:checkhealth mars`.

## Code Structure and Imports

- Directory layout:
  - `init.lua`: entrypoint.
  - `lsp/*.lua`: native LSP server configs, auto-loaded by
    `vim.lsp.enable()` (Neovim >= 0.11 convention). One file per server.
  - `lua/mars/core/`: options, keymaps, autocmds. Zero plugin dependencies.
  - `lua/mars/ui/`: statusline, winbar, dashboard, notify. Zero plugin
    dependencies.
  - `lua/mars/lang/`: per-language modules (php.lua, laravel.lua, blade.lua,
    twig.lua, antlers.lua, ts.lua, format.lua, lint.lua).
  - `lua/mars/plugins/`: one file per external plugin: `vim.pack.add()` call
    plus that plugin's config.
  - `lua/mars/pack.lua`: the lazy-load wrapper around `vim.pack`.
  - `lua/mars/local.lua`: gitignored, user-specific overrides. Not part of
    the repo; see `lua/mars/local.lua.example`.
- Do not manually `require` files under `lua/mars/core/`, `lua/mars/ui/`, or
  `lua/mars/lang/`: they are auto-loaded (see `init.lua`'s `require_dir`
  helper). `lsp/*.lua` files are auto-loaded by Neovim itself, not by Mars's
  own code.
- User-specific customization (e.g. `vim.g.have_nerd_font`) belongs in
  `lua/mars/local.lua` (copy `lua/mars/local.lua.example`), not in a tracked
  file: it's gitignored and loaded last, after everything else, so it can
  override any option/global/keymap/plugin config without ever producing an
  uncommitted diff.
- Plugin specs live in `lua/mars/plugins/*.lua`. Defer loading through
  `lua/mars/pack.lua`'s wrapper when a plugin doesn't need to be available at
  startup; otherwise call `vim.pack.add()` directly.
- Keep modules light on side effects; initialize in setup functions where
  possible, not at require time.

## Types and Documentation

- Use EmmyLua annotations on public functions and module APIs:

  ```lua
  --- Brief description
  ---@param path string
  ---@return boolean
  local function file_exists(path) ... end
  ```

- Prefer module-level doc comments for helpers and plugin specs to explain
  intent, assumptions, and notable side effects.

## Naming Conventions

- Locals/fields: `snake_case`.
- Modules: `snake_case`, matching their file name.
- Files: lowercase with hyphens/underscores where appropriate.
- Functions: verb_noun (for example, `file_exists`).
- Globals: only `vim` is guaranteed today. Additional globals are only
  introduced when a dependency sets one itself (e.g. a plugin exposing
  `_G.Laravel`): never add a new global from first-party Mars code. Check
  `.luarc.json`/`.emmyrc.json` for the current authoritative list and keep
  them in sync when a new global is genuinely required.

## Error Handling and Logging

- Wrap risky calls with `pcall` or guard checks (for example, binaries).
- Fail fast on hard misconfigurations; fallback gracefully for optional
  tools.
- Notify via `vim.notify` or `vim.notify_once` with levels from
  `vim.log.levels`.
- Use `vim.schedule` for notifications from callbacks or async contexts.
- Prefer Neovim diagnostics and `vim.notify` over printing to stdout/stderr.

## Plugin and Config Patterns

- Autocmds: `vim.api.nvim_create_autocmd` in `lua/mars/core/autocmds/`; keep
  idempotent and lightweight.
- Keymaps: `vim.keymap.set` in `lua/mars/core/keymaps/`.
- Options: `lua/mars/core/options.lua`.
- LSP servers: `lsp/*.lua`, one file per server, using
  `vim.lsp.config()`/`vim.lsp.enable()`. Do not depend on nvim-lspconfig as a
  runtime plugin: copy the relevant server config data from its source when
  bootstrapping a new server, then vendor it here.
- Treesitter and Mason: `lua/mars/plugins/treesitter.lua`,
  `lua/mars/plugins/mason.lua`.
- Formatting: `lua/mars/lang/format.lua`; event `BufWritePre`; manual command
  `:MarsFormat`.
- Linting (edited-file diagnostics): `lua/mars/lang/lint.lua`; manual command
  `:Lint`.
- Plugin manager: `vim.pack.add()` calls live in `lua/mars/plugins/*.lua`;
  never edit the generated lockfile by hand.

## Repo Notes and File Map

- Stylua: `stylua.toml` (2-space indent, width 120).
- Selene: `selene.toml` + `neovim.yml` (Lua linting for this repo's own
  code).
- Lua LS / EmmyLua globals: `.luarc.json`, `.emmyrc.json`.
- Health checks: `lua/mars/health.lua` (`:checkhealth mars`).
- Formatting config: `lua/mars/lang/format.lua`.
- Linting config: `lua/mars/lang/lint.lua`.
- LSP setup: `lsp/*.lua`.
- Project skills: `.agents/skills/code`, `.agents/skills/format`,
  `.agents/skills/lint`, `.agents/skills/commit`.

## Do and Do Not

- Do: run `stylua .` and `selene .` before submitting changes.
- Do: use Neovim APIs (`vim.*`) instead of shelling out or reaching for a
  plugin when possible: see Native-First Philosophy above.
- Do not: add a plugin that overlaps one of the already-approved exceptions,
  or a plugin at all when a native API covers the need.
- Do not: manually require auto-loaded config directories.
- Do not: introduce new globals from first-party code; keep modules
  explicit.
- Do not: manually edit `vim.pack`'s lockfile; it's machine-generated.

## Useful Commands (Cheat Sheet)

- Format Lua (this repo): `stylua .`
- Lint Lua (this repo): `selene .`
- In Neovim: `:source %`, `:checkhealth mars`, `:MarsFormat`, `:Lint`,
  `:messages`

## Resources

- [INSPIRATION.md](INSPIRATION.md): curated pool of reference repos and
  docs (native-first configs, well-documented configs, project-website
  examples) to consult before implementing a milestone.
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

Maintain readability, minimal side effects, and clear notifications. Favor
the smallest native solution that correctly solves the problem, and treat
every new plugin dependency as a decision that needs justifying.
