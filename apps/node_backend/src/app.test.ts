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
  it('skips the generic api limiter for chat sync polling', async () => {
    for (let i = 0; i < 110; i += 1) {
      const response = await fetch(
        `${baseUrl}/api/chat/sync/${encodeURIComponent('session:default:main')}?afterSeq=${i}`,
      );
      expect(response.status).toBe(200);
    }
  });

  it('skips the generic api limiter for authenticated platform routes', async () => {
    for (let i = 0; i < 110; i += 1) {
      const response = await fetch(`${baseUrl}/api/v1/platform/noop`, {
        headers: {
          Authorization: 'Bearer test-platform-key',
          'X-Bricks-Plugin-Id': 'plugin_local_main',
        },
      });
      expect(response.status).toBe(200);
    }
  });

  it('skips the generic api limiter for authenticated chat respond requests', async () => {
    for (let i = 0; i < 110; i += 1) {
      const response = await fetch(`${baseUrl}/api/chat/respond`, {
        method: 'POST',
        headers: {
          Authorization: 'Bearer test-user-token',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          taskId: `task-${i}`,
          idempotencyKey: `idem-${i}`,
          channelId: 'default',
          sessionId: 'session:default:main',
          userMessageId: `msg-user-${i}`,
          assistantMessageId: `msg-assistant-${i}`,
          userMessage: 'hello',
        }),
      });
      expect(response.status).toBe(200);
    }
  });

  it('still applies the generic api limiter to non-sync api routes', async () => {
    let response: globalThis.Response | null = null;
    for (let i = 0; i < 101; i += 1) {
      response = await fetch(`${baseUrl}/api/config/noop`);
    }

    expect(response?.status).toBe(429);
  });
});
