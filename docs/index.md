---
layout: home

hero:
  name: "Mars"
  text: "A native-first Neovim configuration"
  tagline: >-
    Minimal, focused on PHP work (Laravel and WordPress), built on as few
    plugins as modern Neovim's own APIs allow.
  image:
    src: /favicon.svg
    alt: Mars
  actions:
    - theme: brand
      text: Why Mars
      link: /guide/what-is-mars
    - theme: alt
      text: Installation
      link: /guide/installation
    - theme: alt
      text: View on GitHub
      link: https://github.com/joanlopez/nvim-mars

features:
  - icon: 🪐
    title: Native-first
    details: >-
      Defaults to Neovim >= 0.12's own APIs: vim.lsp, vim.pack,
      vim.diagnostic, native completion and snippets; before ever reaching
      for a plugin.
  - icon: 🧩
    title: A handful of exceptions
    details: >-
      Only genuinely singular-purpose, hard-to-reproduce needs get a plugin:
      a fuzzy picker, git gutter signs, a debugger UI, an AI chat surface.
  - icon: 🐘
    title: PHP first
    details: >-
      PHPantom on Laravel and Composer projects, Intelephense with WordPress
      stubs on WordPress ones, picked automatically. Pint, PHPStan, Blade,
      Twig and Laravel pickers included.
  - icon: 🧪
    title: Dogfooded and CI-checked
    details: >-
      Runs standalone via NVIM_APPNAME=nvim-mars, formatted with Stylua and
      linted with Selene on every push.
---
