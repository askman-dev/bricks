import express from 'express';
import jwt from 'jsonwebtoken';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { vi } from 'vitest';
import { issuePlatformAccessToken } from '../middleware/platformAuth.js';
import {
  MAX_PLATFORM_ACK_BATCH_SIZE,
  ackPlatformEvents,
  listPlatformEvents,
  createPlatformMessage,
  patchPlatformMessage,
} from '../services/platformIntegrationService.js';

vi.mock('../services/platformIntegrationService.js', () => ({
  MAX_PLATFORM_ACK_BATCH_SIZE: 200,
  listPlatformEvents: vi.fn(async () => ({ nextCursor: 'cur_0', events: [] })),
  ackPlatformEvents: vi.fn(async () => ({ ok: true })),
  createPlatformMessage: vi.fn(async () => ({ messageId: 'msg_test', conversationId: 'conv_1', revision: 1 })),
  patchPlatformMessage: vi.fn(),
  resolveConversation: vi.fn(),
}));

vi.mock('../services/platformNodeService.js', () => ({
  getPlatformNodeByPluginId: vi.fn(async () => ({
    nodeId: 'node_default',
    displayName: 'openclaw 1',
    pluginId: 'plugin_local_main',
  })),
}));

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';
let createPlatformRouter: typeof import('./platform.js').createPlatformRouter;

beforeAll(async () => {
  process.env.BRICKS_PLATFORM_API_KEY = 'test-platform-key';
  process.env.BRICKS_PLATFORM_API_SCOPES = 'events:read,events:ack,messages:write,conversations:read';
  process.env.JWT_SECRET = 'test-jwt-secret';

  const app = express();
  app.use(express.json());
  const platformModule = await import('./platform.js');
  createPlatformRouter = platformModule.createPlatformRouter;
  const { default: platformRoutes } = platformModule;
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

  it('rejects oversized ack payloads before calling the service', async () => {
    vi.mocked(ackPlatformEvents).mockClear();

    const response = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({
        ackedEventIds: Array.from({ length: MAX_PLATFORM_ACK_BATCH_SIZE + 1 }, (_, index) => `evt_${index + 1}`),
        cursor: 'cur_1',
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string; message?: string } };
    expect(body.error?.code).toBe('INVALID_PAYLOAD');
    expect(body.error?.message).toContain(String(MAX_PLATFORM_ACK_BATCH_SIZE));
    expect(vi.mocked(ackPlatformEvents)).not.toHaveBeenCalled();
  });

  it('returns 400 when service throws INVALID_ACKED_EVENT_IDS', async () => {
    vi.mocked(ackPlatformEvents).mockRejectedValueOnce(new Error('INVALID_ACKED_EVENT_IDS'));

    const response = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['bad-id'], cursor: 'cur_1' }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string; message?: string } };
    expect(body.error?.code).toBe('INVALID_PAYLOAD');
    expect(body.error?.message).toContain('malformed');
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

  it('rejects JWT platform token without pluginId claim', async () => {
    const jwtToken = jwt.sign(
      {
        typ: 'platform_plugin',
        userId: 'user-123',
        scopes: ['events:ack'],
      },
      process.env.JWT_SECRET!,
      { expiresIn: '1h' },
    );
    const response = await fetch(`${baseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${jwtToken}`,
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_2'], cursor: 'cur_2' }),
    });

    expect(response.status).toBe(401);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('UNAUTHORIZED');
  });

  it('JWT events listing passes userId to service', async () => {
    const jwtToken = issuePlatformAccessToken({
      userId: 'user-456',
      pluginId: 'plugin_local_main',
      scopes: ['events:read'],
      expiresIn: '1h',
    });

    vi.mocked(listPlatformEvents).mockClear();

    const response = await fetch(`${baseUrl}/api/v1/platform/events?cursor=cur_0`, {
      headers: {
        Authorization: `Bearer ${jwtToken}`,
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
    });

    expect(response.status).toBe(200);
    expect(vi.mocked(listPlatformEvents)).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'user-456' }),
    );
  });

  it('JWT token prevents userId override in POST /messages', async () => {
    const jwtToken = issuePlatformAccessToken({
      userId: 'user-123',
      pluginId: 'plugin_local_main',
      scopes: ['messages:write'],
      expiresIn: '1h',
    });

    const response = await fetch(`${baseUrl}/api/v1/platform/messages`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${jwtToken}`,
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({
        userId: 'different-user',
        conversationId: 'conv-1',
        channelId: 'ch-1',
        text: 'hello',
      }),
    });

    expect(response.status).toBe(403);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('FORBIDDEN');
  });

  it('JWT token uses token userId when body userId is absent in POST /messages', async () => {
    const jwtToken = issuePlatformAccessToken({
      userId: 'user-123',
      pluginId: 'plugin_local_main',
      scopes: ['messages:write'],
      expiresIn: '1h',
    });

    vi.mocked(createPlatformMessage).mockClear();

    const response = await fetch(`${baseUrl}/api/v1/platform/messages`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${jwtToken}`,
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({
        conversationId: 'conv-1',
        channelId: 'ch-1',
        text: 'hello',
      }),
    });

    expect(response.status).toBe(200);
    expect(vi.mocked(createPlatformMessage)).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'user-123' }),
    );
  });

  it('rejects oversized text in POST /messages', async () => {
    vi.mocked(createPlatformMessage).mockClear();
    const response = await fetch(`${baseUrl}/api/v1/platform/messages`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({
        userId: 'user-123',
        conversationId: 'conv-1',
        channelId: 'ch-1',
        text: 'x'.repeat(12001),
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('INVALID_PAYLOAD');
    expect(vi.mocked(createPlatformMessage)).not.toHaveBeenCalled();
  });

  it('rejects oversized text in PATCH /messages/:messageId', async () => {
    vi.mocked(patchPlatformMessage).mockClear();
    const response = await fetch(`${baseUrl}/api/v1/platform/messages/msg-1`, {
      method: 'PATCH',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({
        userId: 'user-123',
        text: 'x'.repeat(12001),
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('INVALID_PAYLOAD');
    expect(vi.mocked(patchPlatformMessage)).not.toHaveBeenCalled();
  });
});

describe('platform SSE events stream', () => {
  it('returns SSE content type and streams events', async () => {
    vi.mocked(listPlatformEvents)
      .mockResolvedValueOnce({ nextCursor: 'cur_1', events: [] })
      .mockResolvedValueOnce({
        nextCursor: 'cur_2',
        events: [
          {
            eventId: 'evt_sse_1',
            eventType: 'message.created',
            workspaceId: 'ws_1',
            conversationId: 'conv_1',
            payload: { text: 'hello from SSE' },
          },
        ],
      });

    const response = await fetch(`${baseUrl}/api/v1/platform/events/stream?cursor=cur_0`, {
      headers: {
        Authorization: 'Bearer test-platform-key',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
    });

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('text/event-stream');

    // Read chunks until we receive a data event, then abort.
    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    let received = '';
    let foundData = false;

    // Poll for up to 5 seconds to let the SSE poll fire.
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline && !foundData) {
      const { done, value } = await reader.read();
      if (done) break;
      received += decoder.decode(value, { stream: true });
      if (received.includes('data:')) {
        foundData = true;
      }
    }

    reader.cancel();

    expect(foundData).toBe(true);
    const dataLine = received
      .split('\n')
      .find((l) => l.startsWith('data:'))
      ?.replace(/^data:\s*/, '');
    expect(dataLine).toBeDefined();
    const parsed = JSON.parse(dataLine!) as { events?: Array<{ eventId?: string }> };
    expect(parsed.events?.[0]?.eventId).toBe('evt_sse_1');
  });

  it('requires cursor parameter', async () => {
    const response = await fetch(`${baseUrl}/api/v1/platform/events/stream`, {
      headers: {
        Authorization: 'Bearer test-platform-key',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('INVALID_CURSOR');
  });
});

describe('platform route rate limiting', () => {
  let limitedServer: ReturnType<express.Express['listen']> | null = null;
  let limitedBaseUrl = '';

  beforeAll(async () => {
    const app = express();
    app.use(express.json());
    app.use(
      '/api/v1/platform',
      createPlatformRouter({
        rateLimit: {
          windowMs: 60 * 1000,
          readMax: 1,
          writeMax: 1,
        },
      }),
    );

    await new Promise<void>((resolve) => {
      limitedServer = app.listen(0, '127.0.0.1', () => {
        const address = limitedServer?.address();
        if (address && typeof address === 'object') {
          limitedBaseUrl = `http://127.0.0.1:${address.port}`;
        }
        resolve();
      });
    });
  });

  afterAll(async () => {
    await new Promise<void>((resolve, reject) => {
      if (!limitedServer) {
        resolve();
        return;
      }
      limitedServer.close((err) => {
        if (err) {
          reject(err);
          return;
        }
        resolve();
      });
    });
  });

  it('keys read limits by pluginId:userId for JWT requests', async () => {
    const user1Token = issuePlatformAccessToken({
      userId: 'user-1',
      pluginId: 'plugin_local_main',
      scopes: ['events:read'],
      expiresIn: '1h',
    });
    const user2Token = issuePlatformAccessToken({
      userId: 'user-2',
      pluginId: 'plugin_local_main',
      scopes: ['events:read'],
      expiresIn: '1h',
    });

    const first = await fetch(`${limitedBaseUrl}/api/v1/platform/events?cursor=cur_0`, {
      headers: {
        Authorization: `Bearer ${user1Token}`,
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
    });
    const secondUser = await fetch(`${limitedBaseUrl}/api/v1/platform/events?cursor=cur_0`, {
      headers: {
        Authorization: `Bearer ${user2Token}`,
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
    });
    const limited = await fetch(`${limitedBaseUrl}/api/v1/platform/events?cursor=cur_0`, {
      headers: {
        Authorization: `Bearer ${user1Token}`,
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
    });

    expect(first.status).toBe(200);
    expect(secondUser.status).toBe(200);
    expect(limited.status).toBe(429);

    const body = (await limited.json()) as { error?: { code?: string; retryable?: boolean } };
    expect(body.error?.code).toBe('RATE_LIMITED');
    expect(body.error?.retryable).toBe(true);
    expect(limited.headers.get('retry-after')).toBeTruthy();
  });

  it('returns retryable 429 responses for platform writes', async () => {
    vi.mocked(ackPlatformEvents).mockClear();

    const first = await fetch(`${limitedBaseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_1'], cursor: 'cur_1' }),
    });
    const limited = await fetch(`${limitedBaseUrl}/api/v1/platform/events/ack`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-platform-key',
        'Content-Type': 'application/json',
        'X-Bricks-Plugin-Id': 'plugin_local_main',
      },
      body: JSON.stringify({ ackedEventIds: ['evt_2'], cursor: 'cur_2' }),
    });

    expect(first.status).toBe(200);
    expect(limited.status).toBe(429);
    const body = (await limited.json()) as { error?: { code?: string; retryable?: boolean; message?: string } };
    expect(body.error?.code).toBe('RATE_LIMITED');
    expect(body.error?.retryable).toBe(true);
    expect(body.error?.message).toContain('platform write');
    expect(limited.headers.get('retry-after')).toBeTruthy();
  });
});
