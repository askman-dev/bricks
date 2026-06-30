import express from 'express';
import { mkdtemp, rm, writeFile, mkdir } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { serviceMock } = vi.hoisted(() => ({
  serviceMock: {
    getChannelSiteBySlug: vi.fn(),
    publicSiteDomain: vi.fn(() => 'craft-spaces.bricks.cool'),
    webDistPath: vi.fn(),
  },
}));

vi.mock('../services/channelSiteService.js', () => serviceMock);

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
});
