import express from 'express';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

const runMigrationsMock = vi.fn(async () => {});

const authRouter = express.Router();
const configRouter = express.Router();
const llmRouter = express.Router();
const chatRouter = express.Router();
const platformRouter = express.Router();
const resourcesRouter = express.Router();
const mediaRouter = express.Router();
const channelSiteApiRouter = express.Router();
const cronRouter = express.Router();
const channelSiteHostRouter = express.Router();

authRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

configRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

llmRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

chatRouter.get('/sync/:sessionId', (_req, res) => {
  res.json({ messages: [], lastSeqId: 0 });
});

chatRouter.post('/respond', (_req, res) => {
  res.json({ ok: true });
});

platformRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

resourcesRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

mediaRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

channelSiteApiRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

cronRouter.get('/noop', (_req, res) => {
  res.json({ ok: true });
});

vi.mock('./db/migrate.js', () => ({
  runMigrations: runMigrationsMock,
}));

vi.mock('./routes/auth.js', () => ({
  default: authRouter,
}));

vi.mock('./routes/config.js', () => ({
  default: configRouter,
}));

vi.mock('./routes/llm.js', () => ({
  default: llmRouter,
}));

vi.mock('./routes/chat.js', () => ({
  default: chatRouter,
}));

vi.mock('./routes/platform.js', () => ({
  default: platformRouter,
}));

vi.mock('./routes/resources.js', () => ({
  default: resourcesRouter,
}));

vi.mock('./routes/media.js', () => ({
  default: mediaRouter,
}));

vi.mock('./routes/channelSiteApi.js', () => ({
  default: channelSiteApiRouter,
}));

vi.mock('./routes/cron.js', () => ({
  default: cronRouter,
}));

vi.mock('./routes/channelSiteHost.js', () => ({
  default: channelSiteHostRouter,
}));

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';
let staticRoot = '';
let previousStaticRoot: string | undefined;

beforeAll(async () => {
  previousStaticRoot = process.env.BRICKS_STATIC_ROOT;
  staticRoot = await mkdtemp(path.join(os.tmpdir(), 'bricks-static-'));
  await writeFile(path.join(staticRoot, 'index.html'), '<!doctype html><title>Bricks</title>');
  await writeFile(path.join(staticRoot, 'main.dart.js'), 'console.log("app")');
  await writeFile(path.join(staticRoot, 'flutter.js'), 'console.log("flutter")');
  await writeFile(path.join(staticRoot, 'asset.txt'), 'asset');
  process.env.BRICKS_STATIC_ROOT = staticRoot;

  const { default: app } = await import('./app.js');

  await new Promise<void>((resolve) => {
    server = app.listen(0, '127.0.0.1', () => {
      const address = server?.address();
      if (address && typeof address === 'object') {
        baseUrl = `http://127.0.0.1:${address.port}`;
      }
      resolve();
    });
  });
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) => {
    if (!server) {
      resolve();
      return;
    }
    server.close((err) => {
      if (err) {
        reject(err);
        return;
      }
      resolve();
    });
  });
  if (previousStaticRoot === undefined) {
    delete process.env.BRICKS_STATIC_ROOT;
  } else {
    process.env.BRICKS_STATIC_ROOT = previousStaticRoot;
  }
  if (staticRoot) {
    await rm(staticRoot, { recursive: true, force: true });
  }
});

describe('app migrations', () => {
  it('skips request-time migrations when AUTO_MIGRATE is false', async () => {
    const previousAutoMigrate = process.env.AUTO_MIGRATE;
    process.env.AUTO_MIGRATE = 'false';
    runMigrationsMock.mockClear();

    try {
      const response = await fetch(`${baseUrl}/api/health`);
      expect(response.status).toBe(200);
      expect(runMigrationsMock).not.toHaveBeenCalled();
    } finally {
      if (previousAutoMigrate === undefined) {
        delete process.env.AUTO_MIGRATE;
      } else {
        process.env.AUTO_MIGRATE = previousAutoMigrate;
      }
    }
  });
});

describe('app rate limiting', () => {
  it('keeps auth routes reachable through /api/auth mount', async () => {
    const response = await fetch(`${baseUrl}/api/auth/noop`);
    expect(response.status).toBe(200);
  });

  it('does not apply a coarse global limiter to non-auth api routes', async () => {
    for (let i = 0; i < 130; i += 1) {
      const response = await fetch(`${baseUrl}/api/config/noop`);
      expect(response.status).toBe(200);
    }
  });
});

describe('app security headers', () => {
  it('allows Flutter Web bootstrap scripts under CSP', async () => {
    const response = await fetch(`${baseUrl}/api/health`);
    expect(response.status).toBe(200);

    const csp = response.headers.get('content-security-policy');
    expect(csp).toContain("script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com");
    expect(csp).toContain("connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com");
    expect(csp).toContain("worker-src 'self' blob:");
  });
});

describe('app static cache headers', () => {
  it('does not cache Flutter app shell files with unversioned names', async () => {
    for (const pathname of ['/', '/main.dart.js', '/flutter.js']) {
      const response = await fetch(`${baseUrl}${pathname}`);
      expect(response.status).toBe(200);
      expect(response.headers.get('cache-control')).toContain('no-store');
    }
  });

  it('does not cache SPA fallback index responses', async () => {
    const response = await fetch(`${baseUrl}/chat/thread-1`);
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toContain('no-store');
  });

  it('keeps non-shell static assets on a short cache policy', async () => {
    const response = await fetch(`${baseUrl}/asset.txt`);
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toBe('public, max-age=60');
  });
});
