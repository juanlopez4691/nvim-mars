# Architecture

This document describes how Mars is actually put together today: the
directory layout, how modules get loaded, the `vim.pack` lazy-loading
pattern, and the native-vs-plugin decisions made so far. For the *rule* that
drives those decisions and the day-to-day conventions (formatting, linting,
commits), see [AGENTS.md](AGENTS.md). This file is the "how the pieces fit
together" companion to that.

Mars is built incrementally (see AGENTS.md's Project Status), so a couple of
things described here are flatter or smaller than the aspirational shape
sketched elsewhere in the repo's own docs: noted inline where that's the
case, rather than glossed over.

## Directory Layout

```text
init.lua                # Entrypoint
lsp/                     # Native LSP server configs (vim.lsp.enable convention)
lua/mars/
├── core/                # Options, editing, LSP enable, diagnostics, netrw, terminals, session
├── ui/                  # Statusline, winbar, dashboard, notify, indent, patterns, colorscheme
├── lang/                # Formatting, linting, snippets, tool resolution, blade/antlers filetype setup
├── plugins/              # One file per external plugin (vim.pack.add + config)
├── helpers/             # Shared on-demand helpers (debounce, color, term, text, php_project)
├── pack.lua             # Lazy-load wrapper around vim.pack
├── health.lua            # :checkhealth mars
└── local.lua.example    # Template for the gitignored lua/mars/local.lua
```

### `init.lua`

The entrypoint. Sets `mapleader`/`maplocalleader`, defines the `require_dir`
auto-load helper (below), calls it for `core`, `plugins`, `ui`, and `lang` in
that order, then `pcall(require, "mars.local")` as the very last step.

### `lsp/*.lua`

One file per LSP server, each returning a plain `vim.lsp.Config` table (see
`:help lsp-config`). Several are explicitly vendored from nvim-lspconfig's
own `lsp/*.lua` sources, the file header comments say so, as a reference
starting point, not a runtime dependency; `lsp/intelephense.lua` and
`lsp/lua_ls.lua` are the clearest examples, each extended with Mars-specific
behavior (global php-stubs discovery; a Neovim-config-aware `on_init` that
only augments the `vim`/LuaJIT globals when editing Mars's own config).

14 servers exist today: `antlersls`, `docker_compose_language_service`,
`dockerls`, `eslint`, `intelephense`, `jsonls`, `laravel_ls`, `lua_ls`,
`marksman`, `phpantom`, `tailwindcss`, `taplo`, `twiggy_language_server`,
`vtsls`.

These files are not `require_dir`'d: see [LSP Activation](#lsp-activation)
below for how they actually get turned on.

#### Two PHP servers, one filetype

`intelephense` and `phpantom` both declare `filetypes = { "php" }`, and both
stay enabled at all times. What keeps them from fighting is `root_dir`:
Neovim only starts a server when its `root_dir` resolver calls `on_dir`, so
each one inspects the buffer and either claims it or returns without calling
back.

The shared test is `lua/mars/helpers/php_project.lua`, which walks up from
the buffer looking for `wp-config.php`, `wp-content` or `wp-includes`.
Finding one means WordPress, and themes or plugins living under a
`wp-content` ancestor count too. Intelephense claims those buffers, for its
stubs; PHPantom (`phpantom_lsp`) claims everything else, Laravel and plain
Composer projects included.

Either way the workspace root is the nearest `composer.json`/`.git`, not the
WordPress install root, so a nested plugin or theme repo indexes itself
rather than the entire site. `lsp/intelephense.lua` also carries the stub
catalogue and discovers globally installed `php-stubs/*` packages under
`~/.composer` or `~/.config/composer`.

### `lua/mars/core/`: zero plugin dependencies

The biggest directory, grouped roughly by what each module does:

- **Editor setup**: `options.lua` (editor options, plus the
  `vim.g.have_nerd_font` default), `lines.lua` (number/cursorline modes per
  focus), `scroll.lua`, `splits.lua` (directional navigation and resize),
  `qol.lua` (yank highlight and other small autocmds), `bigfile.lua` (turns
  expensive features off past a size threshold).
- **LSP**: `lsp.lua` (enables every `lsp/*.lua` config), `completion.lua`
  (native `vim.lsp.completion`), `diagnostics.lua` (inline chips plus
  quickfix/location-list commands), `lsp_references.lua` (document-highlight
  under the cursor), `renaming.lua`, `rootdir.lua` (on-demand project root),
  `dap.lua` (the `<leader>d` debug keymaps driving nvim-dap).
- **Editing**: `pairs.lua`, `surround.lua`, `autotag.lua`, `tagpairs.lua`,
  `textobjects.lua`, `navigation.lua` (treesitter textobject motions),
  `jump.lua` (two-char jump labels), `editing.lua` (line moves and visual
  indent), `insert.lua`, `clipboard.lua`.
- **Tools**: `netrw.lua` (netrw restyled as a tree-view sidebar),
  `terminal.lua` (the generic `<leader>t` terminals), `lazygit.lua` and
  `scooter.lua` (floating TUI terminals), `session.lua` (`:mksession`-based
  per-directory session save/restore).

Most of these replace what a distribution would pull a plugin in for
(mini.pairs, vim-surround, nvim-ts-autotag, mini.ai, flash.nvim,
nvim-treesitter-textobjects); where that's the case, the module's header
comment names the plugin it stands in for.

Each module owns both the keymaps and autocmds for the feature it
implements, colocated with the logic; for example `lazygit.lua` defines
its `<leader>gg` keymap right next to the `WinClosed`/`VimResized` autocmds
that manage its floating window. This is the actual convention in the repo
today; it's flatter than the `lua/mars/core/keymaps/` /
`lua/mars/core/autocmds/` split described in AGENTS.md's "Plugin and Config
Patterns" section, which reads as the aspirational end state rather than
what's on disk right now (see [Gaps](#gaps-between-agentsmd-and-the-current-tree)).

### `lua/mars/ui/`: zero plugin dependencies

`statusline.lua` and `winbar.lua` (expression-based `vim.o.statusline` /
`vim.o.winbar`, each resolving the target window via
`g:statusline_winid`), `dashboard.lua` (a native `VimEnter` start screen
whose picker actions route through `plugins/fzf-lua.lua`'s shared wrapper,
with user-configurable header art), `notify.lua` (a `vim.notify` replacement
rendering stacked floating windows, top-right, auto-dismissing per
severity), `indent.lua` (extmark indent guides over the visible range, with
the current level highlighted), `patterns.lua` (extmark-based
TODO/FIXME/HACK/WARN/NOTE/PERF comment highlighting plus hex color swatches,
debounced to the visible window range), `borders.lua` (the shared float
border style, read from `vim.g.mars_border_style` at point of use), and
`colorscheme.lua` (the built-in `default` colorscheme plus a handful of
highlight-group overrides for window separators and the winbar).

### `lua/mars/lang/`

Per-language and per-tooling modules. Today: `blade.lua` (registers the
`blade`/`antlers` filetypes and maps both onto the `html` treesitter parser,
since neither has a dedicated parser in nvim-treesitter's standard set),
`format.lua` (`BufWritePre` formatter dispatch driven by a
filetype-to-formatter table, plus `:MarsFormat`), `lint.lua` (external
linter runner, currently phpstan/phpcs for PHP, for filetypes not already
covered by LSP-published diagnostics, plus `:Lint`), `snippets.lua` (manual
`vim.snippet.expand()` triggered by `<Tab>` on a matching trigger word, data
vendored from friendly-snippets as static JSON under `lang/snippets/*.json`),
and `tools.lua` (shared executable resolution: project-local
`vendor/bin`/`node_modules/.bin`, then Mason's install dir, then bare
`PATH`).

There is no dedicated `php.lua`, `laravel.lua`, `twig.lua`, `antlers.lua`,
or `ts.lua` module yet: those languages' behavior today comes from their
`lsp/*.lua` config (`intelephense.lua`, `phpantom.lua`,
`twiggy_language_server.lua`, `antlersls.lua`, `vtsls.lua`) plus the shared
`format`/`lint`/`snippets`/`tools` modules above, not a per-language file.
The one piece of PHP logic that lives outside `lsp/` is the WordPress test
in `helpers/php_project.lua`, shared by the two PHP servers. See
[Gaps](#gaps-between-agentsmd-and-the-current-tree).

### `lua/mars/plugins/`: one file per external plugin

`blade-nav.lua`, `dap.lua`, `dap-lua.lua`, `dap-php.lua`, `fzf-lua.lua`,
`gitsigns.lua`, `laravel.lua`, `mason.lua`, `opencode.lua`, `treesitter.lua`,
`which-key.lua`. Each calls
`require("mars.pack").add({...})` to register its plugin(s), then either
configures eagerly or defers via `require("mars.pack").on({...})`: see
[The vim.pack Lazy-Load Wrapper](#the-vimpack-lazy-load-wrapper).

### `lua/mars/helpers/`

Shared modules with no feature of their own, required on demand by any
`core`/`ui`/`lang`/`plugins` module that needs them. Today: `debounce.lua`
(a per-key debounce used by the indent-guide/pattern redraws and lint),
`color.lua` (WCAG-readable foreground picked for a hex background),
`term.lua` (the floating-terminal lifecycle shared by lazygit, scooter, and
opencode), `text.lua` (display-width truncation and `%`-escaping for the
statusline/winbar/notify/diagnostics renderers), and `php_project.lua` (the
WordPress-install lookup both PHP servers gate their `root_dir` on). None
are auto-loaded by `require_dir`.

### `lua/mars/pack.lua`

The lazy-load wrapper around `vim.pack`, detailed below.

### `lua/mars/local.lua` (gitignored)

User-specific overrides, copied from `lua/mars/local.lua.example`.
`pcall(require, "mars.local")` runs last in `init.lua`, after every
`require_dir` call, so it can override any option, global, keymap, or
plugin config without ever producing a tracked diff. The example file
demonstrates all three: `vim.g.have_nerd_font`, a plain `vim.o` override,
and an extra keymap.

### `lua/mars/health.lua`

Implements `:checkhealth mars` per the `:help health-dev` module-discovery
convention (`require("mars.health").check()`). Nothing in Mars's own code
requires this file directly: Neovim's `:checkhealth` machinery finds it by
name.

## Module Loading Conventions

`init.lua` defines one helper, `require_dir(dir)`:

```lua
local function require_dir(dir)
  local files = vim.api.nvim_get_runtime_file(("lua/mars/%s/*.lua"):format(dir), true)
  table.sort(files)
  for _, file in ipairs(files) do
    local module = file:match("lua/(.*)%.lua$"):gsub("/", ".")
    require(module)
  end
end
```

It searches `'runtimepath'` (via `nvim_get_runtime_file`, `all = true`)
rather than a hardcoded path, so it works whether Mars is the active
`NVIM_APPNAME` config or vendored inside another one. Files are sorted
before requiring, so load order within a directory is deterministic and
alphabetical. It's a no-op for a directory that doesn't exist yet; adding a
new top-level category under `lua/mars/` doesn't require touching
`init.lua`, only adding the matching `require_dir("newdir")` call once that
category is introduced.

`init.lua` calls it for four directories, in this order: `core`, `plugins`,
`ui`, `lang`. The order matters; `core` establishes options, the LSP
enable list, and diagnostics config before anything else runs; `plugins`
registers every `vim.pack` spec (and, for the eager ones, configures them)
before `ui`/`lang` modules that might delegate to a plugin's wrapper at load
time (e.g. `ui/dashboard.lua` routing its picker actions through
`plugins/fzf-lua.lua`).

What is **not** covered by `require_dir` and is loaded a different way:

- `lsp/*.lua`: never manually required by Mars code at all; see
  [LSP Activation](#lsp-activation).
- `lua/mars/helpers/*.lua`: required explicitly, on demand, by whichever
  module needs them (`require("mars.helpers.debounce")`,
  `require("mars.helpers.text")`, ...), never auto-loaded.
- `lua/mars/pack.lua` and `lua/mars/health.lua`: required explicitly by
  whatever consumes them (`require("mars.pack")` from any `plugins/*.lua`
  file; `require("mars.health")` by Neovim's own `:checkhealth`
  discovery), not auto-loaded.
- `lua/mars/local.lua`: `pcall(require, "mars.local")`, called once,
  explicitly, as the last line of `init.lua`.
- `lua/mars/lang/snippets/*.json`: not Lua modules; read directly by
  `snippets.lua` via `nvim_get_runtime_file` + `vim.json.decode`, not
  `require`'d.

### LSP Activation

`lua/mars/core/lsp.lua` (itself loaded by `require_dir("core")`) is what
actually turns every `lsp/*.lua` config on:

```lua
local names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
  names[#names + 1] = vim.fn.fnamemodify(file, ":t:r")
end

vim.lsp.enable(names)
```

It scans the runtime path for every `lsp/*.lua` file, takes each one's
basename as the server name, and calls `vim.lsp.enable()` once for the
whole list. Dropping a new `lsp/foo.lua` file in is the entire integration
step: this scan-and-enable list never needs to be maintained by hand, and
nothing in Mars's own code ever `require()`s an `lsp/*.lua` file directly;
Neovim's built-in LSP config convention (`:help lsp-config`) sources each
one lazily itself once that server name is enabled and a matching buffer
attaches.

## The vim.pack Lazy-Load Wrapper

`vim.pack` (Neovim ≥ 0.12) has no built-in event/filetype/command-based
lazy-loading of its own: `lua/mars/pack.lua` is a thin first-party
wrapper that adds it. Two functions:

**`M.add(specs)`**: calls `vim.pack.add(specs, { load = false, confirm =
false })`. `vim.pack.add()` itself is cheap to call eagerly for every
plugin: with `load = false` it installs the plugin to disk and makes it
`require()`-able, but does *not* run its `plugin/`/`ftdetect/` scripts.
`confirm = false` skips the install-confirmation prompt, since the plugin
list is already reviewed by editing this config file: unlike
`vim.pack.update()`, left at its default, where reviewing a diff of
*changes* is genuinely useful.

**`M.on(opts)`**: defers `opts.config()` (typically a
`require("plugin").setup(...)` call) until one of `opts.event` or
`opts.ft` fires, running the callback at most once via an internal
`done` guard. What actually costs boot time isn't registering a
plugin with `vim.pack`, it's calling that plugin's own `setup()`; `M.on()`
is what defers *that*.

In practice, `lua/mars/plugins/*.lua` doesn't uniformly lean on `M.on()`;
each file picks whatever lazy trigger actually fits that plugin:

| Plugin | Trigger | Notes |
| --- | --- | --- |
| `gitsigns.lua` | `event = {"BufReadPre", "BufNewFile"}` | Configures on first buffer read. |
| `which-key.lua` | `event = "VimEnter"` | |
| `mason.lua` | `event = "VimEnter"` | Also exposes `:MarsMasonInstall`, guarded by its own `mason_ready` flag, since that command is first-party, not the plugin's own. |
| `laravel.lua` | `ft = {"php", "blade"}` | The `ft` trigger only fires once, so the actual Laravel-project check (`artisan` present) happens *inside* `config()`; a `php`/`blade` buffer opened outside a Laravel project doesn't burn the trigger; keymaps still load laravel.nvim on demand the first time one is used later in the session. |
| `fzf-lua.lua` | none (no `M.on` call) | No single natural event/filetype trigger fits a picker. Instead each keymap wraps a local `use()` helper that calls `fzf-lua`'s own `setup()` the first time any picker keymap is actually pressed, guarded by a local `is_setup` flag. |
| `treesitter.lua` | none (configured eagerly, right after `M.add`) | nvim-treesitter (main branch) doesn't support lazy-loading per its own README. |
| `blade-nav.lua` | none (only `M.add` + a config global) | Fully self-initializing: its own `ftplugin/{php,blade,vue}` scripts run automatically the moment a matching buffer opens: `load = false` still lets `ftplugin/` fire; only `plugin/` and `ftdetect/` are skipped. Mars only installs it and pre-sets `vim.g.blade_nav`. |

## Native-vs-Plugin Decisions

The rule (AGENTS.md's Native-First Philosophy, restated briefly here):
default to Neovim's native APIs; only add a plugin when it is genuinely
singular-purpose and *materially hard* to reproduce natively, not merely
convenient. Below is what that rule has actually produced in this repo so
far: the plugins kept as approved exceptions, and the ones explicitly
declined in favor of a native module, with the module that replaced each.

### Approved exceptions, and their current state

| Plugin | Why it's an exception | Status |
| --- | --- | --- |
| `fzf-lua` | Fuzzy file/grep/buffer/symbol picker; no native fuzzy-match UI exists. | Installed (`plugins/fzf-lua.lua`); files/live-grep/buffers/oldfiles under `<leader>f*`, git status/commits/branches under `<leader>g{s,c,b}`, LSP document/workspace symbols under `<leader>c{s,S,w}`. Also the picker backend for `dashboard.lua` and laravel.nvim. |
| `gitsigns.nvim` | Git gutter signs, staging, blame; nontrivial diff-parsing and debounced rendering. | Installed (`plugins/gitsigns.lua`); hunk stage/reset/preview/nav, buffer stage/reset, line/toggle blame, `diffthis`, all under `<leader>gh*` and `]h`/`[h`. |
| `which-key.nvim` | Leader-key hint popup and group labels; no native equivalent. | Installed (`plugins/which-key.lua`); declares the `<leader>{a,c,d,f,g,l,o,q,r,s,t,y}` group labels. |
| `mason.nvim` | Cross-platform external tool/binary installer. | Installed (`plugins/mason.lua`); a small first-party `ensure_tools()` (intelephense, phpantom_lsp, phpstan, phpcs, phpcbf, php-cs-fixer, pint, prettierd, vtsls, blade-formatter, and the rest of the language toolchain, exposed as `:MarsMasonInstall`) stands in for `mason-tool-installer`; no `mason-lspconfig`; servers are wired natively via `vim.lsp.enable`. |
| `nvim-treesitter` (main) | Parser install/update only; highlighting/folding stays native. | Installed (`plugins/treesitter.lua`); installs parsers, starts `vim.treesitter.*` highlighting per filetype, and wires `foldexpr` to treesitter with an LSP-folding upgrade on `LspAttach` when a client supports it. |
| `nvim-dap` + `nvim-dap-ui` + `nvim-dap-virtual-text` + `mason-nvim-dap` | Debugging is the explicit "complex, worth a plugin" case. | Installed; `plugins/dap.lua` (the stack + gutter signs + dap-ui listeners), `plugins/dap-php.lua` (Xdebug adapter and launch configs, skipped when `.vscode/launch.json` exists), `plugins/dap-lua.lua` (osv adapter for Neovim's own Lua, lazy-loaded on `lua`), and `core/dap.lua` with the `<leader>d` debug keymaps. |
| `opencode.nvim` | AI chat/agent integration; the sole AI surface. | Installed (`plugins/opencode.lua`); a right-split terminal running `opencode --port`, plus ask/prompt/operator/scroll action keymaps under `<leader>o*` (`go`/`goo` alongside). |
| `adalessa/laravel.nvim` | Laravel-specific pickers/commands, upstream. | Installed (`plugins/laravel.lua`); Artisan/routes/make/resources pickers, Actions/Hub/Command Center, and a resource-aware `gf` fallback under `<leader>l*`. Pulls in `nui.nvim`, `plenary.nvim`, and `nvim-nio` solely as laravel.nvim's own hard runtime deps; not a general invitation to reach for them elsewhere. |
| `blade-nav.nvim` | Blade tag-completion / navigation source. | Installed (`plugins/blade-nav.lua`); `gf` navigation and inline annotations (routes, views, config/env values, directives, Livewire, Inertia, translations) for Laravel projects, entirely self-initializing via its own `ftplugin` scripts. |

### Declined, and what replaced them

| Plugin | Declined because | Native replacement |
| --- | --- | --- |
| `diffview.nvim` | Diff review is already covered. | The floating lazygit integration (`lua/mars/core/lazygit.lua`) plus `:diffthis` and gitsigns' `<leader>ghd`. |
| `gitlineage.nvim` | Blame/history are already covered. | gitsigns' `<leader>ghb` (full blame) / `<leader>ghB` (toggle current-line blame), plus lazygit. |
| `trouble.nvim` | Native lists already do this. | `vim.diagnostic.setqflist()`/`setloclist()` in `lua/mars/core/diagnostics.lua`, exposed as `:MarsDiagnosticsWorkspace(Errors)` / `:MarsDiagnosticsBuffer(Errors)` and `<leader>c{q,Q,l,L}`. |
| `todo-comments.nvim` / `mini.hipatterns` | Reproducible with extmarks. | `lua/mars/ui/patterns.lua`; TODO/FIXME/HACK/WARN/NOTE/PERF keyword highlighting (comment-scoped via treesitter) plus hex-color swatches, debounced per visible window range. |

### The rest of the native surface

Not every native module above is a plugin *replacement*: some cover
territory no plugin in this ecosystem was ever being considered for, and
exist simply because the native API was already sufficient: `statusline.lua`
/ `winbar.lua` (expression-based, no statusline plugin), `dashboard.lua` (no
dashboard plugin), `notify.lua` (no notifier plugin), `session.lua`
(`:mksession`, no session plugin), the `netrw.lua` sidebar (no file-explorer
plugin), `colorscheme.lua` (built-in `default`, no theme plugin),
`completion.lua` (`vim.lsp.completion`, no completion-engine plugin), and
`snippets.lua` (`vim.snippet`, no snippet-engine plugin).

## Gaps Between AGENTS.md and the Current Tree

AGENTS.md is written as the spec Mars builds toward (see its "Project
Status" section), which means a few things it describes don't match the
repo exactly yet. Documented here rather than silently papered over:

- **`lua/mars/core/keymaps/` and `lua/mars/core/autocmds/`**: AGENTS.md's
  "Plugin and Config Patterns" section describes these as dedicated
  subdirectories. They don't exist; keymaps and autocmds are colocated
  inside the feature module that owns them (see the `core/` section above).
- **`lua/mars/lang/` per-language files**: AGENTS.md's Code Structure
  section lists `php.lua`, `laravel.lua`, `twig.lua`, `antlers.lua`, and
  `ts.lua` as expected members of `lua/mars/lang/`. None exist today; those
  languages are covered by their `lsp/*.lua` config plus the shared
  `format`/`lint`/`snippets`/`tools` modules instead of a dedicated file
  per language.

None of this is a defect to fix as part of writing this document: it's the
honest current state, kept here so this file doesn't silently drift from
what AGENTS.md describes as the target.
