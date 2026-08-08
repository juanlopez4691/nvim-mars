# What is Mars

Mars is a minimal, native-first Neovim (>= 0.12) configuration, tailored for
PHP, Laravel, and web development; built on as few plugins as modern
Neovim's native APIs allow.

Modern Neovim ships native LSP configuration, LSP-driven completion,
snippets, folding, and a plugin manager (`vim.pack`, 0.12+) that make most of
a typical "distribution" unnecessary. Mars leans on those native APIs as far
as they reasonably go, and only reaches for a plugin when something is
genuinely singular-purpose and hard to reproduce: a fuzzy picker, git
gutter signs, a debugger UI.

## Guiding principles

- Rely on native APIs before reaching for a plugin.
- Use the fewest plugins possible, and only for genuinely hard problems.
- Prioritize boot and runtime speed.
- Keep the code modular and pragmatic.
- Enforce Lua formatting and linting at all times.
- Document everything well enough for both humans and AI coding agents to
  contribute confidently.

## Who it's for

Mars is opinionated toward PHP, Laravel, and general web development
(JavaScript/TypeScript, Blade, Twig, Tailwind CSS), but the native-first
approach itself isn't language-specific: see the
[language support table](https://github.com/joanlopez/nvim-mars#language-support)
in the README for the current LSP/formatter/linter matrix.

It's also written to be legible to AI coding agents, not just humans:
[AGENTS.md](https://github.com/joanlopez/nvim-mars/blob/main/AGENTS.md) in
the repository root is the authoritative, repo-specific reference for
contribution conventions, and this documentation site links back to it
rather than duplicating it.

Read on for [why native-first specifically](/guide/why-native-first),
[how to install it](/guide/installation), and an
[architecture overview](/guide/architecture).
