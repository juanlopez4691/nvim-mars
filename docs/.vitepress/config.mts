import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Mars",
  description:
    "A minimal, native-first Neovim (>= 0.12) configuration for PHP, Laravel, and web development.",

  // Served from https://<user>.github.io/nvim-mars/ as a GitHub Pages
  // project site — must match the repository name.
  base: "/nvim-mars/",

  cleanUrls: true,
  lastUpdated: true,

  head: [["link", { rel: "icon", href: "/nvim-mars/favicon.svg" }]],

  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: "/favicon.svg",

    nav: [
      { text: "Guide", link: "/guide/what-is-mars" },
      { text: "Architecture", link: "/guide/architecture" },
      { text: "AGENTS.md", link: "https://github.com/joanlopez/nvim-mars/blob/main/AGENTS.md" },
    ],

    sidebar: [
      {
        text: "Guide",
        items: [
          { text: "What is Mars", link: "/guide/what-is-mars" },
          { text: "Why native-first", link: "/guide/why-native-first" },
          { text: "Installation", link: "/guide/installation" },
          { text: "Architecture overview", link: "/guide/architecture" },
        ],
      },
    ],

    socialLinks: [{ icon: "github", link: "https://github.com/joanlopez/nvim-mars" }],

    footer: {
      message: "Released under the Apache License 2.0.",
      copyright: "Copyright © Joan López",
    },

    search: {
      provider: "local",
    },

    editLink: {
      pattern: "https://github.com/joanlopez/nvim-mars/edit/main/docs/:path",
      text: "Edit this page on GitHub",
    },
  },
});
