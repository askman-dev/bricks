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
  resolveChatScopeRoutingMock,
  resolveScopeInstructionsMock,
  upsertChatScopeSettingMock,
  deleteChatScopeSettingMock,
  claimFirstMessageGeneratedNameAttemptMock,
  completeFirstMessageGeneratedNameMock,
  insertFirstMessageExactNameIfMissingMock,
  archiveChatChannelMock,
  listChatChannelsMock,
  upsertChatChannelMock,
  generateWithUserConfigMock,
  streamWithAgentToolsAndUserConfigMock,
  buildAgentToolsMock,
  getPlatformNodeByNodeIdMock,
  listPlatformNodesMock,
} = vi.hoisted(() => ({
  acceptTaskMock: vi.fn(async () => ({
    taskId: "task-1",
    sessionId: "session:default:main",
    state: "accepted",
    acceptedAt: "2026-04-17T07:00:00.000Z",
  })),
  listSessionMessagesForModelMock: vi.fn(async () => []),
  syncMessagesMock: vi.fn(
    async (): Promise<{ messages: Array<Record<string, unknown>>; lastSeqId: number }> => ({
      messages: [],
      lastSeqId: 0,
    }),
  ),
  upsertMessagesMock: vi.fn(async () => ({ lastSeqId: 7 })),
  listUserScopesMock: vi.fn(async () => []),
  listChatScopeSettingsMock: vi.fn(
    async (): Promise<Array<Record<string, unknown>>> => [],
  ),
  resolveChatScopeRoutingMock: vi.fn(
    async (): Promise<{ router: "local" | "plugin"; nodeId: string | null }> => ({
      router: "local",
      nodeId: null,
    }),
  ),
  resolveScopeInstructionsMock: vi.fn(async () => ({
    channelInstructions: null,
    threadInstructions: null,
  })),
  upsertChatScopeSettingMock: vi.fn(async () => ({
    scopeType: "channel",
    channelId: "default",
    threadId: null,
    router: "plugin",
    nodeId: "node-default",
    createdAt: "2026-04-17T07:00:00.000Z",
    updatedAt: "2026-04-17T07:00:00.000Z",
  })),
  deleteChatScopeSettingMock: vi.fn(async () => ({ deleted: true })),
  claimFirstMessageGeneratedNameAttemptMock: vi.fn(async () => null),
  completeFirstMessageGeneratedNameMock: vi.fn(async () => null),
  insertFirstMessageExactNameIfMissingMock: vi.fn(async () => null),
  archiveChatChannelMock: vi.fn(async () => ({
    channelId: "channel-1",
    threadId: null,
    scopeType: "channel",
    displayName: "项目频道",
    archivedAt: "2026-04-18T08:02:00.000Z",
    createdAt: "2026-04-18T08:00:00.000Z",
    updatedAt: "2026-04-18T08:02:00.000Z",
  })),
  listChatChannelsMock: vi.fn(async () => []),
  upsertChatChannelMock: vi.fn(async () => ({
    channelId: "channel-1",
    threadId: null,
    scopeType: "channel",
    displayName: "项目频道",
    archivedAt: null,
    createdAt: "2026-04-18T08:00:00.000Z",
    updatedAt: "2026-04-18T08:00:00.000Z",
  })),
  generateWithUserConfigMock: vi.fn(async () => ({
    provider: "anthropic",
    model: "claude-sonnet-4-5",
    text: "Generated Thread Name",
  })),
  streamWithAgentToolsAndUserConfigMock: vi.fn(async () => ({
    textStream: (async function* () {
      yield "sync ";
      yield "reply";
    })(),
    provider: "anthropic",
    modelId: "claude-sonnet-4-5",
  })),
  buildAgentToolsMock: vi.fn(() => ({})),
  getPlatformNodeByNodeIdMock: vi.fn(
    async (
      _userId: string,
      nodeId: string,
    ): Promise<{ nodeId: string; displayName: string; pluginId: string } | null> => ({
      nodeId,
      displayName: nodeId === "node-2" ? "openclaw 2" : "openclaw 1",
      pluginId: nodeId === "node-2" ? "plugin_node_2" : "plugin_local_main",
    }),
  ),
  listPlatformNodesMock: vi.fn(async () => [
    {
      nodeId: "node-default",
      displayName: "openclaw 1",
      pluginId: "plugin_local_main",
      createdAt: "2026-04-17T07:00:00.000Z",
      updatedAt: "2026-04-17T07:00:00.000Z",
    },
  ]),
}));

vi.mock("../services/chatAsyncTransportService.js", () => ({
  acceptTask: acceptTaskMock,
  listSessionMessagesForModel: listSessionMessagesForModelMock,
  listUserScopes: listUserScopesMock,
  syncMessages: syncMessagesMock,
  upsertMessages: upsertMessagesMock,
}));

vi.mock("../services/chatRouterService.js", () => ({
  CHAT_ROUTER_LOCAL: "local",
  CHAT_ROUTER_PLUGIN: "plugin",
  builtinDefaultNodeRef: () => ({
    nodeId: "node_builtin_default",
    nodeName: "Bricks Default",
  }),
  normalizeChatRouterValue: (value: string | null | undefined) => {
    if (value === "local" || value === "default") return "local";
    if (value === "plugin" || value === "openclaw") return "plugin";
    return null;
  },
  deleteChatScopeSetting: deleteChatScopeSettingMock,
  listChatScopeSettings: listChatScopeSettingsMock,
  resolveChatScopeRouting: resolveChatScopeRoutingMock,
  resolveScopeInstructions: resolveScopeInstructionsMock,
  upsertChatScopeSetting: upsertChatScopeSettingMock,
}));

vi.mock("../services/platformNodeService.js", () => ({
  getPlatformNodeByNodeId: getPlatformNodeByNodeIdMock,
  listPlatformNodes: listPlatformNodesMock,
}));

vi.mock("../services/chatChannelService.js", () => ({
  archiveChatChannel: archiveChatChannelMock,
  claimFirstMessageGeneratedNameAttempt: claimFirstMessageGeneratedNameAttemptMock,
  completeFirstMessageGeneratedName: completeFirstMessageGeneratedNameMock,
  insertFirstMessageExactNameIfMissing: insertFirstMessageExactNameIfMissingMock,
  listChatChannels: listChatChannelsMock,
  upsertChatChannel: upsertChatChannelMock,
}));

vi.mock('../services/localAgentLoopService.js', () => ({
  buildAgentTools: buildAgentToolsMock,
}));

vi.mock("../llm/llm_service.js", () => ({
  generateWithUserConfig: generateWithUserConfigMock,
  streamWithAgentToolsAndUserConfig: streamWithAgentToolsAndUserConfigMock,
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
    resolveChatScopeRoutingMock.mockReset();
    resolveChatScopeRoutingMock.mockResolvedValue({
      router: "local",
      nodeId: null,
    });
    upsertChatScopeSettingMock.mockClear();
    resolveScopeInstructionsMock.mockReset();
    resolveScopeInstructionsMock.mockResolvedValue({
      channelInstructions: null,
      threadInstructions: null,
    });
    deleteChatScopeSettingMock.mockClear();
    claimFirstMessageGeneratedNameAttemptMock.mockReset();
    claimFirstMessageGeneratedNameAttemptMock.mockResolvedValue(null);
    completeFirstMessageGeneratedNameMock.mockReset();
    completeFirstMessageGeneratedNameMock.mockResolvedValue(null);
    insertFirstMessageExactNameIfMissingMock.mockReset();
    insertFirstMessageExactNameIfMissingMock.mockResolvedValue(null);
    archiveChatChannelMock.mockClear();
    listChatChannelsMock.mockClear();
    upsertChatChannelMock.mockClear();
    generateWithUserConfigMock.mockReset();
    generateWithUserConfigMock.mockResolvedValue({
      provider: "anthropic",
      model: "claude-sonnet-4-5",
      text: "Generated Thread Name",
    });
    streamWithAgentToolsAndUserConfigMock.mockClear();
    buildAgentToolsMock.mockClear();
    getPlatformNodeByNodeIdMock.mockReset();
    getPlatformNodeByNodeIdMock.mockImplementation(
      async (_userId: string, nodeId: string) => ({
        nodeId,
        displayName: nodeId === "node-2" ? "openclaw 2" : "openclaw 1",
        pluginId: nodeId === "node-2" ? "plugin_node_2" : "plugin_local_main",
      }),
    );
    listPlatformNodesMock.mockClear();
  });

  it("routes plugin scopes to async pending dispatch", async () => {
    resolveChatScopeRoutingMock.mockResolvedValueOnce({
      router: "plugin",
      nodeId: "node-default",
    });

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
    expect(streamWithAgentToolsAndUserConfigMock).not.toHaveBeenCalled();
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-user-1",
        role: "user",
        taskState: "accepted",
        metadata: expect.objectContaining({
          source: "backend.respond.openclaw",
          targetNodeId: "node-default",
          targetNodeName: "openclaw 1",
          targetPluginId: "plugin_local_main",
          pendingAssistantMessageId: "msg-assistant-1",
        }),
      }),
    ]);
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 0);
    });
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-assistant-1",
        role: "assistant",
        taskState: "dispatched",
        content: "",
        metadata: expect.objectContaining({
          agentName: "openclaw 1",
          dispatchPlaceholder: true,
          source: "backend.respond.openclaw",
        }),
      }),
    ]);
  });

  it("falls back to Bricks Default when a saved plugin node no longer exists", async () => {
    resolveChatScopeRoutingMock.mockResolvedValueOnce({
      router: "plugin",
      nodeId: "deleted-node",
    });
    getPlatformNodeByNodeIdMock.mockResolvedValueOnce(null);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "task-fallback-1",
        idempotencyKey: "idem-fallback-1",
        channelId: "default",
        sessionId: "session:default:main",
        userMessageId: "msg-user-fallback-1",
        assistantMessageId: "msg-assistant-fallback-1",
        userMessage: "fallback to default",
      }),
    });

    expect(response.status).toBe(200);
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-user-fallback-1",
        metadata: expect.objectContaining({
          source: "backend.respond",
          targetNodeId: "node_builtin_default",
          targetNodeName: "Bricks Default",
          targetPluginId: null,
        }),
      }),
    ]);

    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 0);
    });
    expect(streamWithAgentToolsAndUserConfigMock).toHaveBeenCalled();
  });

  it("routes default scopes to async accepted and generates reply in background", async () => {
    resolveChatScopeRoutingMock.mockResolvedValueOnce({
      router: "local",
      nodeId: null,
    });

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
          targetNodeId: "node_builtin_default",
          targetNodeName: "Bricks Default",
          targetPluginId: null,
        }),
      }),
    ]);

    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 0);
    });
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-assistant-default-1",
        taskState: "dispatched",
        content: "",
        metadata: expect.objectContaining({
          dispatchPlaceholder: true,
          source: "backend.respond.stream",
        }),
      }),
    ]);
    expect(streamWithAgentToolsAndUserConfigMock).toHaveBeenCalled();
    expect(streamWithAgentToolsAndUserConfigMock).toHaveBeenCalledWith(
      "user-123",
      expect.objectContaining({ messages: expect.any(Array) }),
      expect.any(Object),
      expect.objectContaining({
        maxSteps: 10,
        maxToolCalls: 50,
        timeoutMs: 60000,
      }),
      undefined,
    );
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-assistant-default-1",
        taskState: "dispatched",
      }),
    ]);
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-assistant-default-1",
        role: "assistant",
        taskState: "completed",
        content: "sync reply",
      }),
    ]);
  });

  it("auto-names a non-main thread from the first message and generates one title", async () => {
    insertFirstMessageExactNameIfMissingMock.mockResolvedValueOnce({
      channelId: "channel-1",
      threadId: "thread-1",
      displayName: "explain katago joseki in simple terms",
      source: "first_message_exact",
      generatedNameAttemptedAt: null,
      createdAt: "2026-05-21T00:00:00.000Z",
      updatedAt: "2026-05-21T00:00:00.000Z",
    } as any);
    claimFirstMessageGeneratedNameAttemptMock.mockResolvedValueOnce({
      channelId: "channel-1",
      threadId: "thread-1",
      displayName: "explain katago joseki in simple terms",
      source: "first_message_exact",
      generatedNameAttemptedAt: "2026-05-21T00:00:01.000Z",
      createdAt: "2026-05-21T00:00:00.000Z",
      updatedAt: "2026-05-21T00:00:01.000Z",
    } as any);
    generateWithUserConfigMock.mockResolvedValueOnce({
      provider: "anthropic",
      model: "claude-sonnet-4-5",
      text: '"Katago Joseki Basics"',
    });
    completeFirstMessageGeneratedNameMock.mockResolvedValueOnce({
      channelId: "channel-1",
      threadId: "thread-1",
      displayName: "Katago Joseki Basics",
      source: "first_message_generated",
      generatedNameAttemptedAt: "2026-05-21T00:00:01.000Z",
      createdAt: "2026-05-21T00:00:00.000Z",
      updatedAt: "2026-05-21T00:00:02.000Z",
    } as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "task-thread-name-1",
        idempotencyKey: "idem-thread-name-1",
        channelId: "channel-1",
        threadId: "thread-1",
        sessionId: "session:channel-1:thread-1",
        userMessageId: "msg-u-thread-name-1",
        assistantMessageId: "msg-a-thread-name-1",
        userMessage: "explain katago joseki in simple terms",
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(insertFirstMessageExactNameIfMissingMock).toHaveBeenCalledWith(
      "user-123",
      {
        channelId: "channel-1",
        threadId: "thread-1",
        displayName: "explain katago joseki in simple terms",
      },
    );
    expect(claimFirstMessageGeneratedNameAttemptMock).toHaveBeenCalledWith(
      "user-123",
      {
        channelId: "channel-1",
        threadId: "thread-1",
      },
    );
    expect(generateWithUserConfigMock).toHaveBeenCalledWith(
      "user-123",
      expect.objectContaining({
        maxTokens: 64,
        messages: expect.arrayContaining([
          expect.objectContaining({
            role: "user",
            content: "explain katago joseki in simple terms",
          }),
        ]),
      }),
      undefined,
    );
    expect(completeFirstMessageGeneratedNameMock).toHaveBeenCalledWith(
      "user-123",
      {
        channelId: "channel-1",
        threadId: "thread-1",
        displayName: "Katago Joseki Basics",
      },
    );
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-a-thread-name-1",
        metadata: expect.objectContaining({
          invalidations: [
            {
              kind: "chat.channelNames",
              channelId: "channel-1",
              threadId: "thread-1",
            },
          ],
        }),
      }),
    ]);
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-a-thread-name-1",
        metadata: expect.objectContaining({
          autoThreadName: {
            source: "first_message_generated",
            displayName: "Katago Joseki Basics",
          },
        }),
      }),
    ]);
  });

  it('uses model-driven agent loop for all local respond messages, always passing tools to the streaming function', async () => {
    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer token',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        taskId: 'task-1',
        idempotencyKey: 'idem-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-1',
        assistantMessageId: 'msg-a-1',
        userMessage: '/channel create ops',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(buildAgentToolsMock).toHaveBeenCalledWith('user-123');
    expect(streamWithAgentToolsAndUserConfigMock).toHaveBeenCalled();
  });

  it('also passes agent tools for ordinary (non-slash) natural language chat messages', async () => {
    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer token',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        taskId: 'task-1b',
        idempotencyKey: 'idem-1b',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-1b',
        assistantMessageId: 'msg-a-1b',
        userMessage: 'create a channel called ops',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(buildAgentToolsMock).toHaveBeenCalledWith('user-123');
    expect(streamWithAgentToolsAndUserConfigMock).toHaveBeenCalled();
  });

  it('passes loop control options from request body to the model-driven agent loop', async () => {
    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer token',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        taskId: 'task-2',
        idempotencyKey: 'idem-2',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-2',
        assistantMessageId: 'msg-a-2',
        userMessage: '/set instruction be concise',
        maxSteps: 6,
        maxToolCalls: 10,
        timeoutMs: 30000,
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(streamWithAgentToolsAndUserConfigMock).toHaveBeenCalledWith(
      'user-123',
      expect.objectContaining({ messages: expect.any(Array) }),
      expect.any(Object),
      expect.objectContaining({ maxSteps: 6, maxToolCalls: 10, timeoutMs: 30000 }),
      undefined,
    );
  });

  it("rejects respond payload when maxTokens exceeds upper bound", async () => {
    resolveChatScopeRoutingMock.mockResolvedValueOnce({
      router: "local",
      nodeId: null,
    });

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
        maxTokens: 999999,
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: string };
    expect(body.error).toContain("maxTokens");
    expect(streamWithAgentToolsAndUserConfigMock).not.toHaveBeenCalled();
  });

  it("prefers an explicitly requested plugin node", async () => {
    resolveChatScopeRoutingMock.mockResolvedValueOnce({
      router: "plugin",
      nodeId: "node-default",
    });
    getPlatformNodeByNodeIdMock.mockResolvedValueOnce({
      nodeId: "node-2",
      displayName: "openclaw 2",
      pluginId: "plugin_node_2",
    });

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        taskId: "task-node-2",
        idempotencyKey: "idem-node-2",
        channelId: "default",
        sessionId: "session:default:main",
        userMessageId: "msg-user-node-2",
        assistantMessageId: "msg-assistant-node-2",
        userMessage: "route to node 2",
        nodeId: "node-2",
      }),
    });

    expect(response.status).toBe(200);
    expect(upsertMessagesMock).toHaveBeenCalledWith("user-123", [
      expect.objectContaining({
        messageId: "msg-user-node-2",
        metadata: expect.objectContaining({
          targetNodeId: "node-2",
          targetNodeName: "openclaw 2",
          targetPluginId: "plugin_node_2",
        }),
      }),
    ]);
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

  it("lists scope settings with resolved target metadata", async () => {
    listChatScopeSettingsMock.mockResolvedValueOnce([
      {
        scopeType: "channel",
        channelId: "default",
        threadId: null,
        router: "plugin",
        nodeId: "node-default",
        instructions: null,
        createdAt: "2026-04-17T07:00:00.000Z",
        updatedAt: "2026-04-17T07:00:00.000Z",
      },
      {
        scopeType: "thread",
        channelId: "default",
        threadId: "main",
        router: "local",
        nodeId: null,
        instructions: null,
        createdAt: "2026-04-17T07:00:00.000Z",
        updatedAt: "2026-04-17T07:00:00.000Z",
      },
    ]);

    const response = await fetch(`${baseUrl}/api/chat/scope-settings`);

    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      settings?: Array<Record<string, unknown>>;
    };
    expect(body.settings?.[0]).toEqual(
      expect.objectContaining({
        router: "plugin",
        resolvedTargetNodeId: "node-default",
        resolvedTargetNodeName: "openclaw 1",
        resolvedTargetPluginId: "plugin_local_main",
      }),
    );
    expect(body.settings?.[1]).toEqual(
      expect.objectContaining({
        router: "local",
        resolvedTargetNodeId: "node_builtin_default",
        resolvedTargetNodeName: "Bricks Default",
        resolvedTargetPluginId: null,
      }),
    );
  });

  it("persists nodeId when saving a plugin scope setting", async () => {
    const response = await fetch(`${baseUrl}/api/chat/scope-settings`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        scopeType: "channel",
        channelId: "default",
        router: "plugin",
        nodeId: "node-2",
      }),
    });

    expect(response.status).toBe(200);
    expect(getPlatformNodeByNodeIdMock).toHaveBeenCalledWith("user-123", "node-2");
    expect(upsertChatScopeSettingMock).toHaveBeenCalledWith("user-123", {
      scopeType: "channel",
      channelId: "default",
      threadId: null,
      router: "plugin",
      nodeId: "node-2",
    });
  });

  it("rejects saving a plugin scope setting without nodeId", async () => {
    const response = await fetch(`${baseUrl}/api/chat/scope-settings`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        scopeType: "channel",
        channelId: "default",
        router: "plugin",
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { error?: string };
    expect(body.error).toContain("nodeId is required");
    expect(upsertChatScopeSettingMock).not.toHaveBeenCalled();
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
    resolveChatScopeRoutingMock.mockResolvedValue({
      router: "plugin",
      nodeId: "node-default",
    });

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

  it("lists persisted chat channels", async () => {
    listChatChannelsMock.mockResolvedValueOnce([
      {
        channelId: "channel-1",
        threadId: null,
        scopeType: "channel",
        displayName: "重命名频道",
        archivedAt: null,
        createdAt: "2026-04-18T08:00:00.000Z",
        updatedAt: "2026-04-18T08:01:00.000Z",
      },
    ] as any);

    const response = await fetch(`${baseUrl}/api/chat/channels`);
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      channels?: Array<{ channelId: string; displayName: string }>;
    };
    expect(body.channels?.[0]?.channelId).toBe("channel-1");
    expect(body.channels?.[0]?.displayName).toBe("重命名频道");
  });

  it("upserts channel when displayName is non-empty", async () => {
    const response = await fetch(`${baseUrl}/api/chat/channels`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channelId: "channel-1",
        displayName: "  新频道名  ",
      }),
    });

    expect(response.status).toBe(200);
    expect(upsertChatChannelMock).toHaveBeenCalledWith("user-123", {
      channelId: "channel-1",
      threadId: null,
      displayName: "新频道名",
    });
    expect(archiveChatChannelMock).not.toHaveBeenCalled();
  });

  it("upserts thread channel row when threadId is provided", async () => {
    const response = await fetch(`${baseUrl}/api/chat/channels`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channelId: "channel-1",
        threadId: "sub-1",
        displayName: "  新分区名  ",
      }),
    });

    expect(response.status).toBe(200);
    expect(upsertChatChannelMock).toHaveBeenCalledWith("user-123", {
      channelId: "channel-1",
      threadId: "sub-1",
      displayName: "新分区名",
    });
  });

  it("rejects channel upsert when displayName is null", async () => {
    const response = await fetch(`${baseUrl}/api/chat/channels`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channelId: "channel-1",
        displayName: null,
      }),
    });

    expect(response.status).toBe(400);
    expect(upsertChatChannelMock).not.toHaveBeenCalled();
    expect(archiveChatChannelMock).not.toHaveBeenCalled();
  });

  it("archives channel row through explicit lifecycle endpoint", async () => {
    const response = await fetch(`${baseUrl}/api/chat/channels/archive`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        channelId: "channel-1",
        displayName: "Archived Channel",
      }),
    });

    expect(response.status).toBe(200);
    expect(archiveChatChannelMock).toHaveBeenCalledWith("user-123", {
      channelId: "channel-1",
      threadId: null,
      displayName: "Archived Channel",
    });
    expect(upsertChatChannelMock).not.toHaveBeenCalled();
  });

  it('writes tool_call_start DB message when onToolCallStart callback is triggered', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implTc = async (...args: any[]) => {
      const options = args[3] as {
        onToolCallStart?: (
          toolName: string,
          args: Record<string, unknown>,
          stepIndex: number,
          callIndex: number,
        ) => Promise<void>;
      };
      if (options.onToolCallStart) {
        await options.onToolCallStart('chat_channel_create', { channelId: 'ops' }, 0, 0);
      }
      return {
        textStream: (async function* () {
          yield 'done';
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implTc as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-tc-1',
        idempotencyKey: 'idem-tc-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-tc-1',
        assistantMessageId: 'msg-a-tc-1',
        userMessage: '/create ops',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-tc-1:tc:1:0',
        role: 'assistant',
        content: '',
        taskState: 'dispatched',
        metadata: expect.objectContaining({
          agentLoop: expect.objectContaining({
            phase: 'tool_call_start',
            stepIndex: 1,
            callIndex: 0,
            toolName: 'chat_channel_create',
          }),
        }),
      }),
    ]);
  });

  it('persists tool execution errors and completes the matching tool_call_start message', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implToolError = async (...args: any[]) => {
      const options = args[3] as {
        onToolCallStart?: (
          toolName: string,
          args: Record<string, unknown>,
          stepIndex: number,
          callIndex: number,
        ) => Promise<void>;
        onToolCallError?: (
          toolName: string,
          args: Record<string, unknown>,
          error: unknown,
          stepIndex: number,
          callIndex: number,
        ) => Promise<void>;
      };
      if (options.onToolCallStart) {
        await options.onToolCallStart(
          'table_create',
          { resourceId: 'sports-day-prep', title: 'Sports Day Preparation' },
          2,
          0,
        );
      }
      if (options.onToolCallError) {
        await options.onToolCallError(
          'table_create',
          { resourceId: 'sports-day-prep', title: 'Sports Day Preparation' },
          new Error('SQL_INPUT_ERROR: SQLite input error: no such function: NOW'),
          2,
          0,
        );
      }
      return {
        textStream: (async function* () {
          yield 'fallback table';
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implToolError as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-tool-error-1',
        idempotencyKey: 'idem-tool-error-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-tool-error-1',
        assistantMessageId: 'msg-a-tool-error-1',
        userMessage: 'show me a table',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-tool-error-1:ts:3',
        role: 'assistant',
        taskState: 'failed',
        content: expect.stringContaining('no such function: NOW'),
        metadata: expect.objectContaining({
          agentLoop: expect.objectContaining({
            phase: 'tool_call',
            stepIndex: 3,
            failedCalls: 1,
          }),
          toolCalls: [
            expect.objectContaining({
              toolName: 'table_create',
              args: {
                resourceId: 'sports-day-prep',
                title: 'Sports Day Preparation',
              },
              result: expect.objectContaining({
                ok: false,
                error: expect.objectContaining({
                  message: 'SQL_INPUT_ERROR: SQLite input error: no such function: NOW',
                }),
              }),
            }),
          ],
        }),
      }),
    ]);
    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-tool-error-1:tc:3:0',
        role: 'assistant',
        content: '',
        taskState: 'completed',
        metadata: expect.objectContaining({
          agentLoop: expect.objectContaining({
            phase: 'tool_call_start',
            stepIndex: 3,
            callIndex: 0,
            toolName: 'table_create',
            error: expect.objectContaining({
              message: 'SQL_INPUT_ERROR: SQLite input error: no such function: NOW',
            }),
          }),
        }),
      }),
    ]);
  });

  it('marks empty post-tool final responses as failed with a clear tool-call limit reason', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implToolLimit = async (...args: any[]) => {
      const options = args[3] as {
        onStepFinish?: (
          stepResults: Array<{
            toolName: string;
            args: Record<string, unknown>;
            result: unknown;
          }>,
        ) => Promise<void>;
      };
      if (options.onStepFinish) {
        await options.onStepFinish(
          Array.from({ length: 10 }, (_, index) => ({
            toolName: `tool_${index + 1}`,
            args: { index },
            result: { ok: true },
          })),
        );
      }
      return {
        textStream: (async function* () {
          // Simulates the AI SDK stream ending after tool calls without a
          // subsequent tool-free final text step.
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implToolLimit as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-tool-limit-1',
        idempotencyKey: 'idem-tool-limit-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-tool-limit-1',
        assistantMessageId: 'msg-a-tool-limit-1',
        userMessage: 'use many tools',
        maxToolCalls: 10,
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-tool-limit-1',
        role: 'assistant',
        taskState: 'failed',
        content: expect.stringContaining('tool-call limit was reached (10/10)'),
        metadata: expect.objectContaining({
          agentLoopStopReason: expect.objectContaining({
            type: 'tool_call_limit_reached',
            toolCallCount: 10,
            maxToolCalls: 10,
            stepCount: 1,
            maxSteps: 10,
          }),
        }),
      }),
    ]);
  });

  it('marks empty post-tool final responses as failed with a real timeout reason', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implTimeout = async (...args: any[]) => {
      const options = args[3] as {
        onStepFinish?: (
          stepResults: Array<{
            toolName: string;
            args: Record<string, unknown>;
            result: unknown;
          }>,
        ) => Promise<void>;
      };
      if (options.onStepFinish) {
        await options.onStepFinish([
          {
            toolName: 'todo_list',
            args: {},
            result: { ok: true, data: [] },
          },
        ]);
      }
      return {
        textStream: (async function* () {
          // Simulates the stream being aborted by the per-step timeout after
          // successful tool calls and before any final assistant text appears.
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
        getStopInfo: () => ({
          type: 'timeout_reached',
          timeoutMs: 60000,
          stepIndex: 1,
        }),
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implTimeout as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-timeout-1',
        idempotencyKey: 'idem-timeout-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-timeout-1',
        assistantMessageId: 'msg-a-timeout-1',
        userMessage: 'list my todos',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-timeout-1',
        role: 'assistant',
        taskState: 'failed',
        content: expect.stringContaining('step timeout was reached (60000ms)'),
        metadata: expect.objectContaining({
          agentLoopStopReason: expect.objectContaining({
            type: 'timeout_reached',
            timeoutMs: 60000,
            timeoutStepIndex: 1,
            toolCallCount: 1,
            completedToolCallCount: 1,
            failedToolCallCount: 0,
            maxToolCalls: 50,
            stepCount: 1,
            maxSteps: 10,
          }),
        }),
      }),
    ]);
  });

  it('persists typed invalidations from successful agent tool results', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implInvalidation = async (...args: any[]) => {
      const options = args[3] as {
        onStepFinish?: (
          stepResults: Array<{
            toolName: string;
            args: Record<string, unknown>;
            result: unknown;
          }>,
        ) => Promise<void>;
      };
      if (options.onStepFinish) {
        await options.onStepFinish([
          {
            toolName: 'chat_channel_rename',
            args: { channelId: 'channel-1', displayName: 'Roadmap' },
            result: { ok: true, data: { channelId: 'channel-1' } },
          },
          {
            toolName: 'chat_thread_create',
            args: { channelId: 'channel-1', threadId: 'thread-1' },
            result: { ok: true, data: { channelId: 'channel-1', threadId: 'thread-1' } },
          },
        ]);
      }
      return {
        textStream: (async function* () {
          yield 'updated';
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implInvalidation as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-invalidations-1',
        idempotencyKey: 'idem-invalidations-1',
        channelId: 'channel-1',
        sessionId: 'session:channel-1:main',
        userMessageId: 'msg-u-invalidations-1',
        assistantMessageId: 'msg-a-invalidations-1',
        userMessage: 'rename this channel and create a thread',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    const expectedInvalidations = [
      { kind: 'chat.channelNames', channelId: 'channel-1', threadId: null },
      { kind: 'chat.channelNames', channelId: 'channel-1', threadId: 'thread-1' },
      { kind: 'chat.scopeSettings', channelId: 'channel-1', threadId: 'thread-1' },
    ];
    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-invalidations-1:ts:1',
        metadata: expect.objectContaining({
          invalidations: expectedInvalidations,
        }),
      }),
    ]);
    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-invalidations-1',
        taskState: 'completed',
        content: 'updated',
        metadata: expect.objectContaining({
          invalidations: expectedInvalidations,
        }),
      }),
    ]);
  });

  it('writes reasoning DB message when onReasoningChunk callback is triggered', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implR = async (...args: any[]) => {
      const options = args[3] as {
        onReasoningChunk?: (text: string, stepIndex: number) => Promise<void>;
      };
      if (options.onReasoningChunk) {
        await options.onReasoningChunk('Let me think about this carefully.', 0);
      }
      return {
        textStream: (async function* () {
          yield 'Here is my answer.';
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implR as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-r-1',
        idempotencyKey: 'idem-r-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-r-1',
        assistantMessageId: 'msg-a-r-1',
        userMessage: '/what is 2+2?',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-r-1:r:1',
        role: 'assistant',
        content: 'Let me think about this carefully.',
        taskState: 'dispatched',
        metadata: expect.objectContaining({
          agentLoop: expect.objectContaining({
            phase: 'reasoning',
            stepIndex: 1,
          }),
        }),
      }),
    ]);
  });

  it('writes step_text DB message when onStepTextEnd callback is triggered', async () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const implPt = async (...args: any[]) => {
      const options = args[3] as {
        onStepTextEnd?: (text: string, stepIndex: number) => Promise<void>;
      };
      if (options.onStepTextEnd) {
        await options.onStepTextEnd("I'll look that up for you.", 0);
      }
      return {
        textStream: (async function* () {
          yield 'Here are the results.';
        })(),
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      };
    };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    streamWithAgentToolsAndUserConfigMock.mockImplementationOnce(implPt as any);

    const response = await fetch(`${baseUrl}/api/chat/respond`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        taskId: 'task-pt-1',
        idempotencyKey: 'idem-pt-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        userMessageId: 'msg-u-pt-1',
        assistantMessageId: 'msg-a-pt-1',
        userMessage: '/search for something',
      }),
    });

    expect(response.status).toBe(200);
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(upsertMessagesMock).toHaveBeenCalledWith('user-123', [
      expect.objectContaining({
        messageId: 'msg-a-pt-1:pt:1',
        role: 'assistant',
        content: "I'll look that up for you.",
        taskState: 'dispatched',
        metadata: expect.objectContaining({
          agentLoop: expect.objectContaining({
            phase: 'step_text',
            stepIndex: 1,
          }),
        }),
      }),
    ]);
  });
});
