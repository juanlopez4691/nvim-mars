-- ricardoramirezr/blade-nav.nvim: gf navigation (routes, views, config, env,
-- Blade directives/components, Livewire, Inertia, translations, Vue imports)
-- and inline annotations (resolved config()/env()/__()/trans() values) for
-- Laravel projects.
--
-- Self-initializing: its own ftplugin/{php,blade,vue} files run project
-- detection and setup() automatically when a matching buffer opens (load =
-- false still lets ftplugin/ fire; only plugin/ and ftdetect/ are skipped).
-- Mars only installs it and pre-sets vim.g.blade_nav, which its setup()
-- merges in since the ftplugin loader calls it with no arguments.

require("mars.pack").add({
  { src = "https://github.com/ricardoramirezr/blade-nav.nvim" },
})

vim.g.blade_nav = { integrations = { cmp = false, coq = false } }
