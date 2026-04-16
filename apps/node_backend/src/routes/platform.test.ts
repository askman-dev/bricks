import express from 'express';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { vi } from 'vitest';
import { issuePlatformAccessToken } from '../middleware/platformAuth.js';

vi.mock('../services/platformIntegrationService.js', () => ({
  listPlatformEvents: vi.fn(async () => ({ nextCursor: 'cur_0', events: [] })),
  ackPlatformEvents: vi.fn(async () => ({ ok: true })),
  createPlatformMessage: vi.fn(),
  patchPlatformMessage: vi.fn(),
  resolveConversation: vi.fn(),
}));

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';

beforeAll(async () => {
  process.env.BRICKS_PLATFORM_API_KEY = 'test-platform-key';
  process.env.BRICKS_PLATFORM_API_SCOPES = 'events:read,events:ack,messages:write,conversations:read';
  process.env.JWT_SECRET = 'test-jwt-secret';

  const app = express();
  app.use(express.json());
  const { default: platformRoutes } = await import('./platform.js');
  app.use('/api/v1/platform', platformRoutes);

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

describe('platform route auth and ack constraints', () => {
  it('returns 400 when plugin header is missing', async () => {
    const response = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_1'], cursor: 'cur_1' }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('MISSING_PLUGIN_ID');
  });

  it('rejects pluginId in ack body with 400', async () => {
    const response = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ pluginId: 'forbidden', ackedEventIds: ['evt_1'], cursor: 'cur_1' }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('INVALID_PAYLOAD');
  });

  it('accepts valid ack payload idempotently', async () => {
    const first = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_1'], cursor: 'cur_1' }),
    });

    const second = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_1'], cursor: 'cur_1' }),
    });

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);

    const body = (await second.json()) as { ok?: boolean };
    expect(body.ok).toBe(true);
  });

  it('accepts user-scoped JWT platform token', async () => {
    const jwtToken = issuePlatformAccessToken({
      userId: 'user-123',
      pluginId: 'plugin_local_main',
      scopes: ['events:ack'],
      expiresIn: '1h',
    });
    const response = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${jwtToken}`,
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_2'], cursor: 'cur_2' }),
    });

    expect(response.status).toBe(200);
    const body = (await response.json()) as { ok?: boolean };
    expect(body.ok).toBe(true);
  });
});
