import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Bricks Docs',
  tagline: 'Documentation for Bricks',

  // Production: DOCS_URL=https://bricks.askman.dev
  // Do not include /docs here. /docs belongs to baseUrl.
  url: process.env.DOCS_URL ?? 'http://localhost',
  // Mount the whole Docusaurus site under /docs/.
  baseUrl: process.env.DOCS_BASE_URL ?? '/docs/',

  organizationName: 'bricks',
  projectName: 'bricks-docs',

  future: {
    faster: {
      rspackBundler: true,
    },
  },

  onBrokenLinks: 'warn',

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          path: '../../docs',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
        },
        blog: false,
        pages: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'Bricks Docs',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
      ],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
