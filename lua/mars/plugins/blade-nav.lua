-- ricardoramirezr/blade-nav.nvim: gf navigation (routes, views, config, env,
-- Blade directives/components, Livewire, Inertia, translations, Vue imports)
-- and inline annotations (resolved config()/env()/__()/trans() values) for
-- Laravel projects (see AGENTS.md's approved exception list).
--
-- Fully self-initializing: its own ftplugin/{php,blade,vue} files run
-- Laravel-project detection and call its setup() automatically the moment a
-- matching buffer opens (confirmed directly; `load = false` still lets
-- ftplugin/ fire; only plugin/ and ftdetect/ are skipped). Mars only needs
-- to install it and pre-set its config global, which its setup() merges in
-- as-is since the ftplugin loader calls it with no arguments of its own.
--
-- Only cmp/coq are disabled here; Mars has neither, and its gf integration
-- is buffer-local and falls back to any existing global `gf` mapping (see
-- lua/mars/plugins/laravel.lua) before falling back further to native `gf`,
-- so the two compose without any reconciliation needed on Mars's side.

require("mars.pack").add({
  { src = "https://github.com/ricardoramirezr/blade-nav.nvim" },
})

vim.g.blade_nav = { integrations = { cmp = false, coq = false } }
