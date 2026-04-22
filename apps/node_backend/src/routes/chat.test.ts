import express from "express";
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";

const {
  acceptTaskMock,
  listSessionMessagesForModelMock,
  syncMessagesMock,
  upsertMessagesMock,
  listUserScopesMock,
  listChatScopeSettingsMock,
  resolveChatRouterMock,
  upsertChatScopeSettingMock,
  deleteChatScopeSettingMock,
  listChatChannelNamesMock,
  upsertChatChannelNameMock,
  deleteChatChannelNameMock,
  generateWithUserConfigMock,
} = vi.hoisted(() => ({
  acceptTaskMock: vi.fn(async () => ({
    taskId: "task-1",
    sessionId: "session:default:main",
    state: "accepted",
    acceptedAt: "2026-04-17T07:00:00.000Z",
  })),
  listSessionMessagesForModelMock: vi.fn(async () => []),
  syncMessagesMock: vi.fn(async () => ({ messages: [], lastSeqId: 0 })),
  upsertMessagesMock: vi.fn(async () => ({ lastSeqId: 7 })),
  listUserScopesMock: vi.fn(async () => []),
  listChatScopeSettingsMock: vi.fn(async () => []),
  resolveChatRouterMock: vi.fn(async () => "default"),
  upsertChatScopeSettingMock: vi.fn(async () => ({
    scopeType: "channel",
    channelId: "default",
    threadId: null,
    router: "openclaw",
    createdAt: "2026-04-17T07:00:00.000Z",
    updatedAt: "2026-04-17T07:00:00.000Z",
  })),
  deleteChatScopeSettingMock: vi.fn(async () => ({ deleted: true })),
  listChatChannelNamesMock: vi.fn(async () => []),
  upsertChatChannelNameMock: vi.fn(async () => ({
    channelId: "channel-1",
    displayName: "项目频道",
    createdAt: "2026-04-18T08:00:00.000Z",
    updatedAt: "2026-04-18T08:00:00.000Z",
  })),
  deleteChatChannelNameMock: vi.fn(async () => ({ deleted: true })),
  generateWithUserConfigMock: vi.fn(async () => ({
    text: "sync reply",
    provider: "anthropic",
    model: "claude-sonnet-4-5",
  })),
}));

vi.mock("../services/chatAsyncTransportService.js", () => ({
  acceptTask: acceptTaskMock,
  listSessionMessagesForModel: listSessionMessagesForModelMock,
  listUserScopes: listUserScopesMock,
  syncMessages: syncMessagesMock,
  upsertMessages: upsertMessagesMock,
}));

vi.mock("../services/chatRouterService.js", () => ({
  CHAT_ROUTER_DEFAULT: "default",
  CHAT_ROUTER_OPENCLAW: "openclaw",
  deleteChatScopeSetting: deleteChatScopeSettingMock,
  listChatScopeSettings: listChatScopeSettingsMock,
  resolveChatRouter: resolveChatRouterMock,
  upsertChatScopeSetting: upsertChatScopeSettingMock,
}));

vi.mock("../services/chatChannelNameService.js", () => ({
  deleteChatChannelName: deleteChatChannelNameMock,
  listChatChannelNames: listChatChannelNamesMock,
  upsertChatChannelName: upsertChatChannelNameMock,
}));

vi.mock("../llm/llm_service.js", () => ({
  generateWithUserConfig: generateWithUserConfigMock,
}));

vi.mock("../middleware/auth.js", () => ({
  authenticate: (
    req: express.Request,
    _res: express.Response,
    next: express.NextFunction,
  ) => {
    (req as express.Request & { userId?: string }).userId = "user-123";
    next();
  },
}));

let server: ReturnType<express.Express["listen"]> | null = null;
let baseUrl = "";

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  const { default: chatRoutes } = await import("./chat.js");
  app.use("/api/chat", chatRoutes);

  await new Promise<void>((resolve) => {
    server = app.listen(0, "127.0.0.1", () => {
      const address = server?.address();
      if (address && typeof address === "object") {
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

describe("chat routes", () => {
  beforeEach(() => {
    acceptTaskMock.mockClear();
    listSessionMessagesForModelMock.mockClear();
    syncMessagesMock.mockClear();
    upsertMessagesMock.mockClear();
    listUserScopesMock.mockClear();
    listChatScopeSettingsMock.mockClear();
    resolveChatRouterMock.mockClear();
    upsertChatScopeSettingMock.mockClear();
    deleteChatScopeSettingMock.mockClear();
    listChatChannelNamesMock.mockClear();
    upsertChatChannelNameMock.mockClear();
    deleteChatChannelNameMock.mockClear();
    generateWithUserConfigMock.mockClear();
  });

  it("routes OpenClaw scopes to async pending dispatch", async () => {
    resolveChatRouterMock.mockResolvedValueOnce("openclaw");

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "task-1",
        idempotencyKey: "idem-1",
        channelId: "default",
        sessionId: "session:default:main",
        userMessageId: "msg-user-1",
        assistantMessageId: "msg-assistant-1",
        userMessage: "hello",
      }),
    });

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      mode?: string;
      state?: string;
      text?: string;
      lastSeqId?: number;
    };
    expect(body.mode).toBe("async");
    expect(body.state).toBe("accepted");
    expect(body.text).toBe("");
    expect(body.lastSeqId).toBe(7);
    expect(generateWithUserConfigMock).not.toHaveBeenCalled();
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-user-1",
        role: "user",
        taskState: "accepted",
        metadata: expect.objectContaining({
          source: "backend.respond.openclaw",
          pendingAssistantMessageId: "msg-assistant-1",
        }),
      }),
    ]);
  });

  it("routes default scopes to async accepted and generates reply in background", async () => {
    resolveChatRouterMock.mockResolvedValueOnce("default");

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "task-default-1",
        idempotencyKey: "idem-default-1",
        channelId: "default",
        sessionId: "session:default:main",
        userMessageId: "msg-user-default-1",
        assistantMessageId: "msg-assistant-default-1",
        userMessage: "hello default",
      }),
    });

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      mode?: string;
      state?: string;
      text?: string;
      lastSeqId?: number;
    };
    expect(body.mode).toBe("async");
    expect(body.state).toBe("accepted");
    expect(body.text).toBe("");
    expect(body.lastSeqId).toBe(7);
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-user-default-1",
        role: "user",
        taskState: "accepted",
        metadata: expect.objectContaining({
          source: "backend.respond",
        }),
      }),
    ]);

    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 0);
    });
    expect(generateWithUserConfigMock).toHaveBeenCalled();
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-assistant-default-1",
        role: "assistant",
        taskState: "completed",
      }),
    ]);
  });

  it("rejects respond payload when maxTokens exceeds upper bound", async () => {
    resolveChatRouterMock.mockResolvedValueOnce("default");

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "task-default-2",
        idempotencyKey: "idem-default-2",
        channelId: "default",
        sessionId: "session:default:main",
        userMessageId: "msg-user-default-2",
        assistantMessageId: "msg-assistant-default-2",
        userMessage: "hello default",
        maxTokens: 99999,
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: string };
    expect(body.error).toContain("maxTokens");
    expect(generateWithUserConfigMock).not.toHaveBeenCalled();
  });

  it("supports clearing a scope setting by sending router=null", async () => {
    const response = await fetch(`${baseUrl}/api/chat/scope-settings`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        scopeType: "thread",
        channelId: "default",
        threadId: "main",
        router: null,
      }),
    });

    expect(response.status).toBe(200);
    expect(deleteChatScopeSettingMock).toHaveBeenCalledWith("user-123", {
      scopeType: "thread",
      channelId: "default",
      threadId: "main",
    });
  });

  it("rate limits sync polling per user and session after 120 requests per minute", async () => {
    const encodedSessionId = encodeURIComponent("session:rate-limit:main");

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
    expect(body.error).toContain("Too many sync requests");
  });

  it("SSE events endpoint streams new messages as they arrive", async () => {
    const encodedSessionId = encodeURIComponent("session:sse:main");
    syncMessagesMock
      .mockResolvedValueOnce({ messages: [], lastSeqId: 30 })
      .mockResolvedValueOnce({
        messages: [
          {
            messageId: "bot-msg-1",
            role: "assistant",
            content: "hi from bot",
            writeSeq: 31,
          },
        ],
        lastSeqId: 31,
      });

    const response = await fetch(
      `${baseUrl}/api/chat/events/${encodedSessionId}?afterSeq=30`,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain(
      "text/event-stream",
    );

    // Read chunks until we receive a data event, then abort.
    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    let received = "";
    let foundData = false;

    // Poll for up to 5 seconds to let the SSE poll fire.
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline && !foundData) {
      const { done, value } = await reader.read();
      if (done) break;
      received += decoder.decode(value, { stream: true });
      if (received.includes("data:")) {
        foundData = true;
      }
    }

    reader.cancel();

    expect(foundData).toBe(true);
    const dataLine = received
      .split("\n")
      .find((l) => l.startsWith("data:"))
      ?.replace(/^data:\s*/, "");
    expect(dataLine).toBeDefined();
    const parsed = JSON.parse(dataLine!) as {
      messages?: Array<{ messageId?: string }>;
      lastSeqId?: number;
    };
    expect(parsed.messages?.[0]?.messageId).toBe("bot-msg-1");
    expect(parsed.lastSeqId).toBe(31);
  });

  it("rate limits respond requests per user and session after 120 requests per minute", async () => {
    resolveChatRouterMock.mockResolvedValue("openclaw");

    const sendRespond = async (sessionId: string, suffix: string) =>
      fetch(`${baseUrl}/api/chat/respond`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          taskId: `task-${suffix}`,
          idempotencyKey: `idem-${suffix}`,
          channelId: "default",
          sessionId,
          userMessageId: `msg-user-${suffix}`,
          assistantMessageId: `msg-assistant-${suffix}`,
          userMessage: "hello",
        }),
      });

    for (let i = 0; i < 120; i += 1) {
      const response = await sendRespond(
        "session:respond-rate-limit:a",
        `a-${i}`,
      );
      expect(response.status).toBe(200);
    }

    const limited = await sendRespond(
      "session:respond-rate-limit:a",
      "a-limited",
    );
    expect(limited.status).toBe(429);
    const limitedBody = (await limited.json()) as { error?: string };
    expect(limitedBody.error).toContain("Too many respond requests");

    const differentSession = await sendRespond(
      "session:respond-rate-limit:b",
      "b-1",
    );
    expect(differentSession.status).toBe(200);
  });

  it("lists persisted channel names", async () => {
    listChatChannelNamesMock.mockResolvedValueOnce([
      {
        channelId: "channel-1",
        displayName: "重命名频道",
        createdAt: "2026-04-18T08:00:00.000Z",
        updatedAt: "2026-04-18T08:01:00.000Z",
      },
    ] as any);

    const response = await fetch(`${baseUrl}/api/chat/channel-names`);
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      channelNames?: Array<{ channelId: string; displayName: string }>;
    };
    expect(body.channelNames?.[0]?.channelId).toBe("channel-1");
    expect(body.channelNames?.[0]?.displayName).toBe("重命名频道");
  });

  it("upserts channel name when displayName is non-empty", async () => {
    const response = await fetch(`${baseUrl}/api/chat/channel-names`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channelId: "channel-1",
        displayName: "  新频道名  ",
      }),
    });

    expect(response.status).toBe(200);
    expect(upsertChatChannelNameMock).toHaveBeenCalledWith("user-123", {
      channelId: "channel-1",
      displayName: "新频道名",
    });
    expect(deleteChatChannelNameMock).not.toHaveBeenCalled();
  });

  it("deletes channel name mapping when displayName is null", async () => {
    const response = await fetch(`${baseUrl}/api/chat/channel-names`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channelId: "channel-1",
        displayName: null,
      }),
    });

    expect(response.status).toBe(200);
    expect(deleteChatChannelNameMock).toHaveBeenCalledWith(
      "user-123",
      "channel-1",
    );
    expect(upsertChatChannelNameMock).not.toHaveBeenCalled();
  });
});
