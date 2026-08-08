# Inspiration Sources

Curated pool of external references for building Mars.

## Official Neovim documentation

The primary source of truth: check here before any plugin, for any native
API question.

| Doc | URL | Use for |
| --- | --- | --- |
| Lua API (`vim.*`) | <https://neovim.io/doc/user/lua.html> | `vim.fs.*`, `vim.fn.*`, `vim.keymap.*`, `vim.tbl_*`, `vim.notify`, `vim.snippet.*` |
| Lua usage guide | <https://neovim.io/doc/user/lua-guide.html> | General patterns for Lua-based config |
| Neovim API (`vim.api.*`) | <https://neovim.io/doc/user/api.html> | Low-level buffer/window/autocmd API |
| LSP (`vim.lsp.*`) | <https://neovim.io/doc/user/lsp.html> | `vim.lsp.config`/`vim.lsp.enable`, `vim.lsp.completion` |
| Diagnostics (`vim.diagnostic.*`) | <https://neovim.io/doc/user/diagnostic.html> | Diagnostic display/config |
| Treesitter (`vim.treesitter.*`) | <https://neovim.io/doc/user/treesitter.html> | Highlighting, folding, incremental selection |
| Plugin management (`vim.pack.*`) | <https://neovim.io/doc/user/pack.html> | The native plugin-manager foundation |
| Options reference | <https://neovim.io/doc/user/options.html> | `vim.o.statusline`/`winbar`, all core options |
| Release notes | <https://github.com/neovim/neovim/releases> | What's actually new/stable per version (0.11 native LSP config, 0.12 `vim.pack`); check before assuming a native API exists |

## Most relevant to Mars: read the source of these first

1. **[boltlessengineer/NativeVim](https://github.com/boltlessengineer/NativeVim)** (⭐595): zero-plugin Neovim config. Closest philosophical match to Mars; see how far it pushes native LSP/completion/statusline before Mars's own exception list is finalized.
2. **[ntk148v/leanpack.nvim](https://github.com/ntk148v/leanpack.nvim)**: a tiny lazy-load wrapper on top of `vim.pack`. Solves the exact lazy-loading gap `vim.pack` has; read before writing `lua/mars/pack.lua`.
3. **[nvim-lua/kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)** (⭐31.2k/🍴46.8k): highest-signal example of native LSP/mason/treesitter wiring done cleanly, at roughly Mars's target scale.
4. **[tjdevries/config.nvim](https://github.com/tjdevries/config.nvim)**: a core Neovim/Treesitter contributor's own config; reference for idiomatic `vim.*` usage.
5. **[LazyVim/lazyvim.github.io](https://github.com/LazyVim/lazyvim.github.io)**: Docusaurus-based docs site; concrete comparison point for a docs-site generator decision.

## General-purpose distributions (context, not blueprints)

Mars diverges from all of these on philosophy: useful for feature-coverage
sanity checks, not architecture.

| Repo | Stars/Forks | Notes |
| --- | --- | --- |
| [LazyVim/LazyVim](https://github.com/LazyVim/LazyVim) | ⭐27.1k / 🍴1.8k | Large plugin ecosystem, feature-rich defaults |
| [NvChad/NvChad](https://github.com/NvChad/NvChad) | ⭐28.4k / 🍴2.2k | "Blazing fast" positioning, but plugin-heavy |
| [LunarVim/LunarVim](https://github.com/LunarVim/LunarVim) | ⭐19.3k / 🍴1.5k | IDE-layer, heavier/more opinionated |
| [AstroNvim/AstroNvim](https://github.com/AstroNvim/AstroNvim) | ⭐14.4k / 🍴0.9k | Community-plugin-driven (astrocommunity) |

## Minimal / native-first configs

| Repo | Stars | Notes |
| --- | --- | --- |
| [boltlessengineer/NativeVim](https://github.com/boltlessengineer/NativeVim) | ⭐595 | See "Most relevant" above |
| [ntk148v/leanpack.nvim](https://github.com/ntk148v/leanpack.nvim) | — | See "Most relevant" above |
| [LunarVim/Neovim-from-scratch](https://github.com/LunarVim/Neovim-from-scratch) | ⭐5.6k / 🍴1.1k | Teaching-oriented build-up; predates `vim.pack` |
| [Maik-0000FF/VelocityNvim](https://github.com/Maik-0000FF/VelocityNvim) | ⭐1 | Very new/low-traction real `vim.pack`-native attempt: skim, don't adopt |

No `vim.pack`-based config has real traction yet (0.12 is brand new): Mars
would be a genuinely early entry in this space.

## Well-documented personal configs

| Repo | Stars | Notes |
| --- | --- | --- |
| [ThePrimeagen/init.lua](https://github.com/ThePrimeagen/init.lua) | ⭐4.0k / 🍴0.7k | Widely-cited for clarity |
| [folke/dot](https://github.com/folke/dot) | ⭐1.3k / 🍴62 | A minimal, distro-scaffolding-free personal config |
| [tjdevries/config.nvim](https://github.com/tjdevries/config.nvim) | ⭐601 / 🍴20 | See "Most relevant" above |

Note: no popular config uses an AGENTS.md/CLAUDE.md convention: Mars's
agent-oriented docs are ahead of the curve, not following precedent.

## Project websites

| Site | Repo | Generator | Notes |
| --- | --- | --- | --- |
| lazyvim.github.io | [LazyVim/lazyvim.github.io](https://github.com/LazyVim/lazyvim.github.io) | Docusaurus | Not VitePress, contrary to an earlier assumption |
| astronvim.com | — | Astro (web framework) | Marketing-style landing + docs |
| nvchad.github.io | — | Bespoke SolidJS + UnoCSS | Flashy, heavier to maintain |

**Open decision:** VitePress (lighter, Vue-based) vs Docusaurus (more
batteries-included for versioned docs).

## PHP/Laravel-specific

Nothing beyond what Mars already depends on.
**[adalessa/laravel.nvim](https://github.com/adalessa/laravel.nvim)**
(⭐453/🍴33) is the clear leader in this niche: already Mars's chosen
dependency.
