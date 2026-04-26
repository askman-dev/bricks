import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    {
      type: 'category',
      label: 'Introduction',
      items: ['intro'],
    },
    {
      type: 'category',
      label: 'Product',
      items: ['product/overview'],
    },
    {
      type: 'category',
      label: 'Get Started',
      items: ['get-started/quickstart'],
    },
    {
      type: 'category',
      label: 'Integrations',
      items: ['integrations/openclaw-plugin'],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: ['architecture/system-overview', 'architecture'],
    },
    {
      type: 'category',
      label: 'FAQ',
      items: ['faq/common-issues'],
    },
    {
      type: 'category',
      label: 'Plans',
      items: [
        'plans/2026-04-26-10-20-UTC-docusaurus-doc-ia-restructure',
        'plans/2026-04-21-07-57-UTC-readme-refresh-consolidated-plan',
        'plans/2026-04-08-02-40-UTC-code-map-foundation',
      ],
    },
  ],
};

export default sidebars;
