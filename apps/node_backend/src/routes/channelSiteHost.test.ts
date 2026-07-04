import express from 'express';
import { mkdtemp, rm, writeFile, mkdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { serviceMock, fsMockState } = vi.hoisted(() => ({
  serviceMock: {
    getChannelSiteBySlug: vi.fn(),
    publicSiteDomain: vi.fn(() => 'craft-spaces.bricks.cool'),
    webDistPath: vi.fn(),
  },
  fsMockState: {
    readFileError: null as NodeJS.ErrnoException | null,
  },
}));

vi.mock('../services/channelSiteService.js', () => serviceMock);
vi.mock('node:fs/promises', async (importOriginal) => {
  const actual = await importOriginal<typeof import('node:fs/promises')>();
  const readFile = vi.fn((...args: Parameters<typeof actual.readFile>) => {
    if (fsMockState.readFileError) {
      const error = fsMockState.readFileError;
      fsMockState.readFileError = null;
      return Promise.reject(error);
    }
    return actual.readFile(...args);
  });
  return {
    ...actual,
    readFile,
    default: {
      ...actual,
      readFile,
    },
  };
});

describe('channelSiteHost route', () => {
  let tempDir: string;
  let baseUrl: string;
  let server: ReturnType<express.Express['listen']>;

  beforeEach(async () => {
    tempDir = await mkdtemp(path.join(os.tmpdir(), 'bricks-site-host-'));
    await mkdir(path.join(tempDir, 'assets'), { recursive: true });
    await writeFile(path.join(tempDir, 'index.html'), '<div id="root">site</div>');
    await writeFile(path.join(tempDir, 'assets', 'app.js'), 'console.log("site")');
    serviceMock.getChannelSiteBySlug.mockResolvedValue({
      userId: 'user-1',
      channelId: 'channel-1',
      publicSlug: 's-abc123',
      latestBuildStatus: 'succeeded',
    });
    serviceMock.webDistPath.mockReturnValue(tempDir);

    const { default: route } = await import('./channelSiteHost.js');
    const app = express();
    app.use(route);
    app.use((_req, res) => res.status(404).send('fallback'));
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', () => {
        const address = server.address();
        if (address && typeof address === 'object') {
          baseUrl = `http://127.0.0.1:${address.port}`;
        }
        resolve();
      });
    });
  });

  afterEach(async () => {
    await new Promise<void>((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
    await rm(tempDir, { recursive: true, force: true });
    serviceMock.getChannelSiteBySlug.mockReset();
    serviceMock.webDistPath.mockReset();
    fsMockState.readFileError = null;
  });

  it('serves static files for craft-spaces slug hosts with noindex headers', async () => {
    const response = await fetch(`${baseUrl}/assets/app.js`, {
      headers: { 'X-Forwarded-Host': 's-abc123.craft-spaces.bricks.cool' },
    });

    expect(response.status).toBe(200);
    expect(response.headers.get('x-robots-tag')).toBe('noindex');
    expect(response.headers.get('cache-control')).toBe('public, max-age=31536000, immutable');
    expect(await response.text()).toContain('site');
  });

  it('falls back to index.html for React SPA routes', async () => {
    const response = await fetch(`${baseUrl}/nested/page`, {
      headers: { 'X-Forwarded-Host': 's-abc123.craft-spaces.bricks.cool' },
    });

    expect(response.status).toBe(200);
    expect(response.headers.get('x-robots-tag')).toBe('noindex');
    expect(response.headers.get('cache-control')).toContain('no-store');
    expect(response.headers.get('content-security-policy')).toContain("script-src 'self' https: 'unsafe-inline' 'unsafe-eval'");
    expect(response.headers.get('content-security-policy')).toContain("connect-src 'self' https: wss:");
    expect(await response.text()).toContain('<div id="root">site</div>');
  });

  it('serves the same site through app-host path previews', async () => {
    const response = await fetch(`${baseUrl}/sites/s-abc123/nested/page`);

    expect(response.status).toBe(200);
    expect(response.headers.get('x-robots-tag')).toBe('noindex');
    expect(await response.text()).toContain('<div id="root">site</div>');
  });

  it('redirects path preview roots to a trailing slash so relative assets resolve under the site slug', async () => {
    const response = await fetch(`${baseUrl}/sites/s-abc123?view=live`, {
      redirect: 'manual',
    });

    expect(response.status).toBe(308);
    expect(response.headers.get('location')).toBe('/sites/s-abc123/?view=live');
  });

  it('returns not published instead of 500 when dist index is missing', async () => {
    serviceMock.webDistPath.mockReturnValue(path.join(tempDir, 'missing-dist'));

    const response = await fetch(`${baseUrl}/sites/s-abc123/`);

    expect(response.status).toBe(404);
    expect(response.headers.get('x-robots-tag')).toBe('noindex');
    expect(await response.text()).toBe('Site not published');
  });

  it('returns not published instead of 500 when an asset disappears during read', async () => {
    fsMockState.readFileError = Object.assign(new Error('missing asset'), { code: 'ENOENT' });

    const response = await fetch(`${baseUrl}/assets/app.js`, {
      headers: { 'X-Forwarded-Host': 's-abc123.craft-spaces.bricks.cool' },
    });

    expect(response.status).toBe(404);
    expect(response.headers.get('x-robots-tag')).toBe('noindex');
    expect(await response.text()).toBe('Site not published');
  });
});
