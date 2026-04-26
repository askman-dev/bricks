import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// Resolve the site origin (scheme + host, no trailing slash) used for
// absolute URLs in sitemaps, canonical tags, and Open Graph metadata.
//
// Resolution order:
//   1. DOCS_URL — optional explicit override (e.g. https://bricks.askman.dev)
//   2. VERCEL_PROJECT_PRODUCTION_URL — injected by Vercel on production deployments
//   3. VERCEL_URL — injected by Vercel on preview deployments
//   4. Fail fast — no silent localhost fallback that would corrupt prod metadata
function resolveDocsUrl(): string {
  if (process.env.DOCS_URL) {
    return process.env.DOCS_URL;
  }
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  if (process.env.VERCEL_URL) {
    return `https://${process.env.VERCEL_URL}`;
  }
  throw new Error(
    'Cannot determine docs site URL. ' +
    'Set DOCS_URL explicitly, or deploy via Vercel where ' +
    'VERCEL_PROJECT_PRODUCTION_URL / VERCEL_URL are injected automatically.',
  );
}

const config: Config = {
  title: 'Bricks Docs',
  tagline: 'Documentation for Bricks',

  // Origin resolved at build time — no manual env var configuration required on Vercel.
  url: resolveDocsUrl(),
  // Docs are always mounted at /docs/. No env var needed.
  baseUrl: '/docs/',

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
