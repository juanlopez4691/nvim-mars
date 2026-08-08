# Contributing to Mars

Thanks for considering a contribution. Mars is a personal, native-first
Neovim config: contributions are welcome, but the bar is "does this need a
plugin, or does Neovim already do it." **[AGENTS.md](AGENTS.md) is the
canonical source of truth** for conventions (native-first philosophy, code
structure, naming, commit style, branching). This file is a short, practical
on-ramp; when in doubt, AGENTS.md wins.

## Dev Setup

Mars runs side by side with any other Neovim config via `NVIM_APPNAME`, so
you never need to touch `~/.config/nvim`:

```bash
git clone https://github.com/joanlopez/nvim-mars.git ~/.config/nvim-mars
NVIM_APPNAME=nvim-mars nvim
```

There's no build step: Neovim loads the config directly. While iterating:

- `:source %` reloads the current buffer.
- Restart Neovim to pick up changes that don't cleanly re-source (autocmds,
  plugin specs).
- `:checkhealth mars` verifies required external binaries and the Neovim
  version.
- `:checkhealth` runs the full LSP/formatter/linter diagnostics.
- Check `:messages` after reloading to catch warnings or errors.
- `nvim --headless +qa` is a quick sanity load (doesn't exercise lazy-loaded
  paths: the same check runs in CI, see below).

See AGENTS.md's [Build, Reload, and Health](AGENTS.md#build-reload-and-health)
section for the full details.

## Before You Submit: Format and Lint

This repo's own Lua code must be formatted with Stylua and pass Selene
before you submit a change.

```bash
stylua .   # format all Lua (see stylua.toml: 2-space indent, width 120)
selene .   # lint this repo's Lua (see selene.toml)
```

Both must run clean. Inside Neovim, you can also format the current buffer
with `:MarsFormat` (native formatting module, also triggered on
`BufWritePre`). `:Lint` runs Mars's own diagnostics module against files
*edited inside* Mars (PHP, JS/TS, etc.); that's separate from `selene .`,
which only lints this repo's own Lua.

## CI

Every push and pull request runs `.github/workflows/ci.yml` on
`ubuntu-latest`. It installs pinned versions of Neovim, Stylua, and Selene,
then runs three checks in order:

1. `stylua --check .`: fails if any Lua file isn't already formatted.
2. `selene .`: lints this repo's Lua against `selene.toml`.
3. A headless boot smoke test: launches Neovim under this config
   (`NVIM_APPNAME` pointed at the checked-out repo) with `nvim --headless -c
   'quit'` and fails the build if anything is printed to `:messages` that
   looks like an error.

Run `stylua .` and `selene .` locally before pushing so CI doesn't surprise
you; there's currently no way to run the headless smoke test as a single
local command beyond `nvim --headless +qa` described above.

## Branching and Commits

Full conventions live in AGENTS.md's
[Commit Conventions](AGENTS.md#commit-conventions) and
[Branching](AGENTS.md#branching) sections: read them before opening a PR.
The short version:

- Create a dedicated branch for anything non-trivial or risky:
  `git checkout -b <type>/<brief-description>` (e.g. `feat/native-statusline`).
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
  `type: subject`, explaining *why* the change is made, not what/how.
- One logical change per commit: don't bundle unrelated topics.
- No scope/context suffix in the subject (no `(fixes #123)`, no issue refs).
- Changes to `.md` files use the `docs:` type.
- Use `fix:` for correcting broken behavior, `feat:` for new behavior or
  added robustness/protection (including proactively preventing a class of
  bug).
- Keep history linear: rebase your branch onto `main` before merging, no
  merge commits (`git merge --no-ff` is never used), never merge `main` into
  a feature branch.

## Pull Requests

- Keep a PR focused on a single logical change, matching the one-change-per-
  commit rule above.
- Make sure `stylua --check .` and `selene .` pass locally: CI will re-run
  both plus the headless smoke test.
- Describe *why* the change is needed in the PR description; the diff
  already shows *what* changed.
- If your change touches the plugin list, re-read AGENTS.md's
  [Native-First Philosophy](AGENTS.md#native-first-philosophy) section first
  New plugins need to be genuinely singular-purpose and materially hard to
  reproduce natively, and any overlap with an already-approved exception
  plugin needs discussion before the PR, not after.

## Questions

Open an issue using the templates under `.github/ISSUE_TEMPLATE/`, or start
a discussion on the relevant PR. For anything about *how* to structure a
change (native API vs. plugin, where a module belongs, naming), AGENTS.md is
the reference: it's written to be precise enough for both human and AI
contributors to follow without guessing.
