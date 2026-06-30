import { afterEach, describe, expect, it, vi } from 'vitest';

const { poolMock } = vi.hoisted(() => ({
  poolMock: {
    query: vi.fn(),
  },
}));

vi.mock('../db/index.js', () => ({
  default: poolMock,
}));

describe('channelSiteService URL generation', () => {
  const previousBaseUrl = process.env.BRICKS_PUBLIC_SITE_BASE_URL;

  afterEach(() => {
    if (previousBaseUrl === undefined) {
      delete process.env.BRICKS_PUBLIC_SITE_BASE_URL;
    } else {
      process.env.BRICKS_PUBLIC_SITE_BASE_URL = previousBaseUrl;
    }
  });

  it('uses path-based site URLs when a public site base URL is configured', async () => {
    process.env.BRICKS_PUBLIC_SITE_BASE_URL = 'https://preview.example.test/';
    const { publicSiteUrl } = await import('./channelSiteService.js');

    expect(publicSiteUrl('s-abc123')).toBe('https://preview.example.test/sites/s-abc123');
  });
});
