import express from 'express';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const {
  acceptTaskMock,
  listSessionHistoryMock,
  listSessionMessagesForModelMock,
  syncMessagesMock,
  upsertMessagesMock,
  listUserScopesMock,
  listChatScopeSettingsMock,
  resolveChatRouterMock,
  upsertChatScopeSettingMock,
  deleteChatScopeSettingMock,
  generateWithUserConfigMock,
} = vi.hoisted(() => ({
  acceptTaskMock: vi.fn(async () => ({
    taskId: 'task-1',
    sessionId: 'session:default:main',
    state: 'accepted',
    acceptedAt: '2026-04-17T07:00:00.000Z',
  })),
  listSessionHistoryMock: vi.fn(async () => ({ messages: [], lastSeqId: 0 })),
  listSessionMessagesForModelMock: vi.fn(async () => []),
  syncMessagesMock: vi.fn(async () => ({ messages: [], lastSeqId: 0 })),
  upsertMessagesMock: vi.fn(async () => ({ lastSeqId: 7 })),
  listUserScopesMock: vi.fn(async () => []),
  listChatScopeSettingsMock: vi.fn(async () => []),
  resolveChatRouterMock: vi.fn(async () => 'default'),
  upsertChatScopeSettingMock: vi.fn(async () => ({
    scopeType: 'channel',
    channelId: 'default',
    threadId: null,
    router: 'openclaw',
    createdAt: '2026-04-17T07:00:00.000Z',
    updatedAt: '2026-04-17T07:00:00.000Z',
  })),
  deleteChatScopeSettingMock: vi.fn(async () => ({ deleted: true })),
  generateWithUserConfigMock: vi.fn(async () => ({
    text: 'sync reply',
    provider: 'anthropic',
    model: 'claude-sonnet-4-5',
  })),
}));

vi.mock('../services/chatAsyncTransportService.js', () => ({
  acceptTask: acceptTaskMock,
  listSessionHistory: listSessionHistoryMock,
  listSessionMessagesForModel: listSessionMessagesForModelMock,
  listUserScopes: listUserScopesMock,
  syncMessages: syncMessagesMock,
  upsertMessages: upsertMessagesMock,
}));

vi.mock('../services/chatRouterService.js', () => ({
  CHAT_ROUTER_DEFAULT: 'default',
  CHAT_ROUTER_OPENCLAW: 'openclaw',
  deleteChatScopeSetting: deleteChatScopeSettingMock,
  listChatScopeSettings: listChatScopeSettingsMock,
  resolveChatRouter: resolveChatRouterMock,
  upsertChatScopeSetting: upsertChatScopeSettingMock,
}));

vi.mock('../llm/llm_service.js', () => ({
  generateWithUserConfig: generateWithUserConfigMock,
}));

vi.mock('../middleware/auth.js', () => ({
  authenticate: (req: express.Request, _res: express.Response, next: express.NextFunction) => {
    (req as express.Request & { userId?: string }).userId = 'user-123';
    next();
  },
}));

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  const { default: chatRoutes } = await import('./chat.js');
  app.use('/api/chat', chatRoutes);

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

describe('chat routes', () => {
  beforeEach(() => {
    acceptTaskMock.mockClear();
    listSessionHistoryMock.mockClear();
    listSessionMessagesForModelMock.mockClear();
    syncMessagesMock.mockClear();
    upsertMessagesMock.mockClear();
    listUserScopesMock.mockClear();
    listChatScopeSettingsMock.mockClear();
    resolveChatRouterMock.mockClear();
    upsertChatScopeSettingMock.mockClear();
    deleteChatScopeSettingMock.mockClear();
    generateWithUserConfigMock.mockClear();
  });

  it('routes OpenClaw scopes to async pending dispatch', async () => {
    resolveChatRouterMock.mockResolvedValueOnce('openclaw');

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-1',
        idempotencyKey: 'idem-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-user-1',
        assistantMessageId: 'msg-assistant-1',
        userMessage: 'hello',
      }),
    });

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      mode?: string;
      state?: string;
      text?: string;
      lastSeqId?: number;
    };
    expect(body.mode).toBe('async');
    expect(body.state).toBe('accepted');
    expect(body.text).toBe('');
    expect(body.lastSeqId).toBe(7);
    expect(generateWithUserConfigMock).not.toHaveBeenCalled();
    expect(upsertMessagesMock).toHaveBeenCalledWith(
      'user-123',
      [
        expect.objectContaining({
          messageId: 'msg-user-1',
          role: 'user',
          taskState: 'accepted',
          metadata: expect.objectContaining({
            source: 'backend.respond.openclaw',
            pendingAssistantMessageId: 'msg-assistant-1',
          }),
        }),
      ],
    );
  });

  it('supports clearing a scope setting by sending router=null', async () => {
    const response = await fetch(`${baseUrl}/api/chat/scope-settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        scopeType: 'thread',
        channelId: 'default',
        threadId: 'main',
        router: null,
      }),
    });

    expect(response.status).toBe(200);
    expect(deleteChatScopeSettingMock).toHaveBeenCalledWith('user-123', {
      scopeType: 'thread',
      channelId: 'default',
      threadId: 'main',
    });
  });

  it('uses createdAt-ordered history window for /history endpoint', async () => {
    listSessionHistoryMock.mockResolvedValueOnce({
      messages: [
        {
          seqId: 21,
          writeSeq: 40,
          messageId: 'm-1',
          taskId: 'task-1',
          channelId: 'default',
          sessionId: 'session:default:main',
          threadId: null,
          role: 'user',
          content: 'hello',
          taskState: 'accepted',
          checkpointCursor: null,
          metadata: null,
          createdAt: '2026-04-20T08:00:00.000Z',
          updatedAt: '2026-04-20T08:00:00.000Z',
        },
      ],
      lastSeqId: 40,
    });

    const encodedSessionId = encodeURIComponent('session:default:main');
    const response = await fetch(
      `${baseUrl}/api/chat/history/${encodedSessionId}?limit=120`,
    );

    expect(response.status).toBe(200);
    expect(listSessionHistoryMock).toHaveBeenCalledWith(
      'user-123',
      'session:default:main',
      { limit: 120 },
    );
    expect(syncMessagesMock).not.toHaveBeenCalledWith(
      'user-123',
      'session:default:main',
      0,
      expect.anything(),
    );
  });

  it('rate limits sync polling per user and session after 120 requests per minute', async () => {
    const encodedSessionId = encodeURIComponent('session:rate-limit:main');

    for (let i = 0; i < 120; i += 1) {
      const response = await fetch(
        `${baseUrl}/api/chat/sync/${encodedSessionId}?afterSeq=${i}`,
      );
      expect(response.status).toBe(200);
    }

    const limited = await fetch(
      `${baseUrl}/api/chat/sync/${encodedSessionId}?afterSeq=999`,
    );

    expect(limited.status).toBe(429);
    const body = (await limited.json()) as { error?: string };
    expect(body.error).toContain('Too many sync requests');
  });
});
