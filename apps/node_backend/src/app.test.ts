import express from 'express';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

const runMigrationsMock = vi.fn(async () => {});

const authRouter = express.Router();
const configRouter = express.Router();
const llmRouter = express.Router();
const chatRouter = express.Router();
const platformRouter = express.Router();

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

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';

beforeAll(async () => {
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
