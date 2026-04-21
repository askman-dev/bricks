import { describe, expect, it, vi } from 'vitest';
import {
  appendReplyText,
  assistantClientTokenForEvent,
  buildNoVisibleReplyText,
  extractReplyText,
  extractIncomingText,
  nextBackoffDelayMs,
  NodeOpenClawPluginRunner,
  resolveRetryDelayMs,
  shouldBackoffPlatformError,
  shouldProcessEvent,
} from '../src/pluginRunner.js';
import { PlatformHttpError } from '../src/platformClient.js';
import { createDefaultState } from '../src/stateStore.js';
import type {
  CreateMessageRequest,
  CreateMessageResponse,
  GetEventsResponse,
  PatchMessageRequest,
  PluginPersistentState,
  ResolveConversationResponse,
} from '../src/types.js';

describe('extractIncomingText', () => {
  it('returns top-level text first', () => {
    expect(extractIncomingText({ text: ' hello ' })).toBe('hello');
  });

  it('falls back to content when text is missing', () => {
    expect(extractIncomingText({ content: ' world ' })).toBe('world');
  });

  it('returns placeholder for empty payload', () => {
    expect(extractIncomingText()).toBe('[empty message]');
  });
});

describe('shouldProcessEvent', () => {
  it('skips assistant/system events', () => {
    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_1',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_1', displayName: 'assistant' } },
        },
      ),
    ).toBe(false);

    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_2',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_2', displayName: 'assistant' } },
        },
      ),
    ).toBe(false);

    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_2b',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_2', displayName: 'system' } },
        },
      ),
    ).toBe(false);
  });

  it('keeps user-created events even when sender userId equals token userId', () => {
    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_3',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_1', displayName: 'user' } },
        },
      ),
    ).toBe(true);
  });

  it('skips plugin-authored events even if the sender label is not assistant', () => {
    expect(
      shouldProcessEvent({
        eventId: 'evt_plugin',
        eventType: 'message.created',
        payload: {
          sender: { userId: 'u_plugin', displayName: 'OpenClaw' },
          metadata: {
            plugin: 'node_openclaw_plugin',
          },
        },
      }),
    ).toBe(false);
  });
});

describe('assistantClientTokenForEvent', () => {
  it('prefers pending assistant message id from payload metadata', () => {
    expect(
      assistantClientTokenForEvent({
        eventId: 'evt_1',
        eventType: 'message.created',
        payload: {
          metadata: {
            pendingAssistantMessageId: 'msg-assistant-1',
          },
        },
      }),
    ).toBe('msg-assistant-1');
  });

  it('falls back to event-derived client token', () => {
    expect(
      assistantClientTokenForEvent({
        eventId: 'evt_2',
        eventType: 'message.created',
      }),
    ).toBe('evt:evt_2');
  });
});

describe('extractReplyText', () => {
  it('returns normalized text payloads', () => {
    expect(extractReplyText({ text: ' hi ' })).toBe('hi');
  });

  it('falls back to media URLs when no text is present', () => {
    expect(
      extractReplyText({
        mediaUrls: ['https://example.com/a.png'],
      }),
    ).toBe('https://example.com/a.png');
  });

  it('appends attachment URLs after text content', () => {
    expect(
      extractReplyText({
        text: 'Look',
        mediaUrls: ['https://example.com/a.png'],
      }),
    ).toBe('Look\n\nhttps://example.com/a.png');
  });
});

describe('appendReplyText', () => {
  it('concatenates visible replies without duplicating identical trailing chunks', () => {
    expect(appendReplyText('', 'first')).toBe('first');
    expect(appendReplyText('first', 'second')).toBe('first\n\nsecond');
    expect(appendReplyText('first\n\nsecond', 'second')).toBe('first\n\nsecond');
  });

  it('deduplicates only exact matches or delimiter-bounded suffix, not arbitrary suffix', () => {
    // "bar" is a suffix of "foobar" but not preceded by \n\n, so it should be appended
    expect(appendReplyText('foobar', 'bar')).toBe('foobar\n\nbar');
    // identical content should be treated as duplicate
    expect(appendReplyText('bar', 'bar')).toBe('bar');
    // exact delimiter-bounded suffix still deduplicates
    expect(appendReplyText('foo\n\nbar', 'bar')).toBe('foo\n\nbar');
  });
});

describe('buildNoVisibleReplyText', () => {
  it('returns a user-visible fallback message', () => {
    expect(buildNoVisibleReplyText('Node OpenClaw Plugin')).toBe(
      'Node OpenClaw Plugin 当前没有返回可显示的回复，请稍后重试。',
    );
  });
});

describe('platform retry backoff helpers', () => {
  it('treats 429 and retryable failures as backoff signals', () => {
    expect(shouldBackoffPlatformError(new PlatformHttpError(429, 'limited'))).toBe(true);
    expect(shouldBackoffPlatformError(new PlatformHttpError(500, 'server', undefined, true))).toBe(true);
    expect(shouldBackoffPlatformError(new Error('boom'))).toBe(false);
  });

  it('advances the capped retry ladder from the current delay', () => {
    expect(nextBackoffDelayMs(2000, 2000)).toBe(4000);
    expect(nextBackoffDelayMs(4000, 2000)).toBe(8000);
    expect(nextBackoffDelayMs(8000, 2000)).toBe(10000);
    expect(nextBackoffDelayMs(30000, 2000)).toBe(30000);
  });

  it('prefers Retry-After over the local backoff ladder', () => {
    expect(
      resolveRetryDelayMs(
        new PlatformHttpError(429, 'limited', 'RATE_LIMITED', true, 30000),
        2000,
        2000,
      ),
    ).toBe(30000);

    expect(
      resolveRetryDelayMs(
        new PlatformHttpError(429, 'limited', 'RATE_LIMITED', true),
        2000,
        2000,
      ),
    ).toBe(4000);
  });
});

describe('NodeOpenClawPluginRunner', () => {
  const config = {
    baseUrl: 'https://example.com',
    token: 'token',
    pluginId: 'plugin',
    tokenUserId: 'user_1',
    pollIntervalMs: 1,
    defaultCursor: 'cur_0',
    stateFilePath: '/tmp/plugin-state.json',
    assistantName: 'Node OpenClaw Plugin',
  };

  it('creates one placeholder and patches it with OpenClaw replies', async () => {
    const eventStream = (async function* () {
      yield {
        nextCursor: 'cur_1',
        events: [
          {
            eventId: 'evt_1',
            eventType: 'message.created',
            workspaceId: 'ws_1',
            conversationId: 'session:general:main',
            payload: {
              text: 'hello',
              sender: {
                userId: 'user_1',
                displayName: 'Alice',
              },
              metadata: {
                pendingAssistantMessageId: 'msg_assistant_1',
              },
            },
          },
        ],
      } as GetEventsResponse;
    })();

    const listenEvents = vi.fn(() => eventStream);
    const resolveConversation = vi.fn<() => Promise<ResolveConversationResponse>>().mockResolvedValue({
      conversationId: 'session:general:main',
      channelId: 'general',
      threadId: 'main',
    });
    const createMessage = vi.fn<(payload: CreateMessageRequest) => Promise<CreateMessageResponse>>()
      .mockResolvedValue({ messageId: 'assistant_message_1' });
    const patchMessage = vi.fn<(messageId: string, payload: PatchMessageRequest) => Promise<{ ok: boolean }>>()
      .mockResolvedValue({ ok: true });
    const ackEvents = vi.fn<() => Promise<{ ok: boolean }>>().mockResolvedValue({ ok: true });
    const save = vi.fn<(state: PluginPersistentState) => Promise<void>>().mockResolvedValue();

    const abortController = new AbortController();
    const runner = new NodeOpenClawPluginRunner(config, {
      client: {
        listenEvents,
        ackEvents,
        resolveConversation,
        createMessage,
        patchMessage,
      },
      stateStore: {
        load: vi.fn().mockResolvedValue(createDefaultState('cur_0')),
        save,
      },
      dispatchBricksInboundMessage: vi.fn(async ({ deliver }) => {
        await deliver({ text: 'text1' });
        await deliver({ text: 'text2' });
        return {
          agentId: 'main',
          sessionKey: 'agent:main:dev-askman-bricks:channel:general',
          storePath: '/tmp/openclaw-sessions',
        };
      }),
    });

    // Run briefly and abort
    setTimeout(() => abortController.abort(), 100);
    await runner.runUntilAbort(abortController.signal);

    expect(createMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 'session:general:main',
        channelId: 'general',
        threadId: 'main',
        role: 'assistant',
        status: 'streaming',
        clientToken: 'msg_assistant_1',
      }),
    );
    expect(patchMessage).toHaveBeenNthCalledWith(
      1,
      'assistant_message_1',
      expect.objectContaining({
        text: 'text1',
        metadata: expect.objectContaining({
          sourceEventId: 'evt_1',
          plugin: 'node_openclaw_plugin',
          handledBy: 'Node OpenClaw Plugin',
        }),
      }),
    );
    expect(patchMessage).toHaveBeenNthCalledWith(
      2,
      'assistant_message_1',
      expect.objectContaining({
        text: 'text1\n\ntext2',
        metadata: expect.objectContaining({
          sourceEventId: 'evt_1',
          plugin: 'node_openclaw_plugin',
          handledBy: 'Node OpenClaw Plugin',
        }),
      }),
    );
    expect(patchMessage).toHaveBeenNthCalledWith(
      3,
      'assistant_message_1',
      expect.objectContaining({
        text: 'text1\n\ntext2',
        metadata: expect.objectContaining({
          sourceEventId: 'evt_1',
          plugin: 'node_openclaw_plugin',
          handledBy: 'Node OpenClaw Plugin',
          openclawAgentId: 'main',
          openclawSessionKey: 'agent:main:dev-askman-bricks:channel:general',
        }),
      }),
    );
    expect(save).toHaveBeenCalled();
    expect(ackEvents).toHaveBeenCalledWith('cur_1', ['evt_1']);
  });

  it('returns immediately when started with an already-aborted signal', async () => {
    const listenEvents = vi.fn();
    const abortController = new AbortController();
    abortController.abort();

    const runner = new NodeOpenClawPluginRunner(config, {
      client: {
        listenEvents,
        ackEvents: vi.fn(),
        resolveConversation: vi.fn(),
        createMessage: vi.fn(),
        patchMessage: vi.fn(),
      } as never,
      stateStore: {
        load: vi.fn().mockResolvedValue(createDefaultState('cur_0')),
        save: vi.fn().mockResolvedValue(undefined),
      },
    });

    await runner.runUntilAbort(abortController.signal);

    expect(listenEvents).not.toHaveBeenCalled();
  });

  it('finalizes an existing placeholder when a retry yields no visible reply', async () => {
    const eventStream = (async function* () {
      yield {
        nextCursor: 'cur_2',
        events: [
          {
            eventId: 'evt_retry_1',
            eventType: 'message.created',
            workspaceId: 'ws_1',
            conversationId: 'session:general:main',
            payload: {
              text: 'hello again',
              sender: {
                userId: 'user_1',
                displayName: 'Alice',
              },
              metadata: {
                pendingAssistantMessageId: 'msg_assistant_retry',
              },
            },
          },
        ],
      } as GetEventsResponse;
    })();

    const listenEvents = vi.fn(() => eventStream);
    const resolveConversation = vi.fn<() => Promise<ResolveConversationResponse>>().mockResolvedValue({
      conversationId: 'session:general:main',
      channelId: 'general',
      threadId: 'main',
    });
    const patchMessage = vi.fn<(messageId: string, payload: PatchMessageRequest) => Promise<{ ok: boolean }>>()
      .mockResolvedValue({ ok: true });
    const ackEvents = vi.fn<() => Promise<{ ok: boolean }>>().mockResolvedValue({ ok: true });
    const save = vi.fn<(state: PluginPersistentState) => Promise<void>>().mockResolvedValue();

    const abortController = new AbortController();
    const runner = new NodeOpenClawPluginRunner(config, {
      client: {
        listenEvents,
        ackEvents,
        resolveConversation,
        createMessage: vi.fn(),
        patchMessage,
      } as never,
      stateStore: {
        load: vi.fn().mockResolvedValue(createDefaultState('cur_1')),
        save,
      },
      dispatchBricksInboundMessage: vi.fn(async () => ({
        agentId: 'main',
        sessionKey: 'agent:main:dev-askman-bricks:channel:general',
        storePath: '/tmp/openclaw-sessions',
      })),
    });
    (runner as any).state = {
      ...createDefaultState('cur_1'),
      clientTokenMessageMap: {
        msg_assistant_retry: 'assistant_message_retry',
      },
    } satisfies PluginPersistentState;

    // Run briefly and abort
    setTimeout(() => abortController.abort(), 100);
    await runner.runUntilAbort(abortController.signal);

    expect(patchMessage).toHaveBeenCalledWith(
      'assistant_message_retry',
      expect.objectContaining({
        text: 'Node OpenClaw Plugin 当前没有返回可显示的回复，请稍后重试。',
        metadata: expect.objectContaining({
          sourceEventId: 'evt_retry_1',
          openclawStatus: 'no_visible_reply',
          openclawReusedPlaceholder: true,
        }),
      }),
    );
    expect(ackEvents).toHaveBeenCalledWith('cur_2', ['evt_retry_1']);
  });

  it('reuses the last successful reply text when a retried event produces no new visible output', async () => {
    const getEvents = vi.fn<() => Promise<GetEventsResponse>>().mockResolvedValue({
      nextCursor: 'cur_3',
      events: [
        {
          eventId: 'evt_retry_2',
          eventType: 'message.created',
          workspaceId: 'ws_1',
          conversationId: 'session:general:main',
          payload: {
            text: 'continue',
            sender: {
              userId: 'user_1',
              displayName: 'Alice',
            },
            metadata: {
              pendingAssistantMessageId: 'msg_assistant_retry_existing_text',
            },
          },
        },
      ],
    });
    const resolveConversation = vi.fn<() => Promise<ResolveConversationResponse>>().mockResolvedValue({
      conversationId: 'session:general:main',
      channelId: 'general',
      threadId: 'main',
    });
    const patchMessage = vi.fn<(messageId: string, payload: PatchMessageRequest) => Promise<{ ok: boolean }>>()
      .mockResolvedValue({ ok: true });
    const ackEvents = vi.fn<() => Promise<{ ok: boolean }>>().mockResolvedValue({ ok: true });
    const save = vi.fn<(state: PluginPersistentState) => Promise<void>>().mockResolvedValue();

    const runner = new NodeOpenClawPluginRunner(config, {
      client: {
        getEvents,
        ackEvents,
        resolveConversation,
        createMessage: vi.fn(),
        patchMessage,
      } as never,
      stateStore: {
        load: vi.fn().mockResolvedValue(createDefaultState('cur_2')),
        save,
      },
      dispatchBricksInboundMessage: vi.fn(async () => ({
        agentId: 'main',
        sessionKey: 'agent:main:dev-askman-bricks:channel:general',
        storePath: '/tmp/openclaw-sessions',
      })),
    });
    (runner as any).state = {
      ...createDefaultState('cur_2'),
      clientTokenMessageMap: {
        msg_assistant_retry_existing_text: 'assistant_message_existing_text',
      },
      clientTokenReplyTextMap: {
        msg_assistant_retry_existing_text: 'already delivered reply',
      },
    } satisfies PluginPersistentState;

    await runner.tick();

    expect(patchMessage).toHaveBeenCalledWith(
      'assistant_message_existing_text',
      expect.objectContaining({
        text: 'already delivered reply',
        metadata: expect.objectContaining({
          openclawStatus: 'no_visible_reply',
        }),
      }),
    );
    expect(ackEvents).toHaveBeenCalledWith('cur_3', ['evt_retry_2']);
  });

  it('persists reply text before a writeback failure so retries can recover the original answer', async () => {
    const getEvents = vi.fn<() => Promise<GetEventsResponse>>().mockResolvedValue({
      nextCursor: 'cur_4',
      events: [
        {
          eventId: 'evt_retry_3',
          eventType: 'message.created',
          workspaceId: 'ws_1',
          conversationId: 'session:general:main',
          payload: {
            text: 'original question',
            sender: {
              userId: 'user_1',
              displayName: 'Alice',
            },
            metadata: {
              pendingAssistantMessageId: 'msg_assistant_retry_saved_text',
            },
          },
        },
      ],
    });
    const resolveConversation = vi.fn<() => Promise<ResolveConversationResponse>>().mockResolvedValue({
      conversationId: 'session:general:main',
      channelId: 'general',
      threadId: 'main',
    });
    const patchMessage = vi.fn<(messageId: string, payload: PatchMessageRequest) => Promise<{ ok: boolean }>>()
      .mockRejectedValue(new PlatformHttpError(429, 'limited', 'RATE_LIMITED', true, 120000));
    const save = vi.fn<(state: PluginPersistentState) => Promise<void>>().mockResolvedValue();
    const initialState = createDefaultState('cur_3');

    const runner = new NodeOpenClawPluginRunner(config, {
      client: {
        getEvents,
        ackEvents: vi.fn(),
        resolveConversation,
        createMessage: vi.fn().mockResolvedValue({
          messageId: 'assistant_message_saved_text',
        } satisfies CreateMessageResponse),
        patchMessage,
      } as never,
      stateStore: {
        load: vi.fn().mockResolvedValue(initialState),
        save,
      },
      dispatchBricksInboundMessage: vi.fn(async ({ deliver }) => {
        await deliver({ text: 'original OpenClaw answer' });
        return {
          agentId: 'main',
          sessionKey: 'agent:main:dev-askman-bricks:channel:general',
          storePath: '/tmp/openclaw-sessions',
        };
      }),
    });

    await expect(runner.tick()).rejects.toMatchObject({
      status: 429,
      message: 'limited',
    });

    const savedReplyState = save.mock.calls
      .map(([state]) => state)
      .find((state) => state.clientTokenReplyTextMap.msg_assistant_retry_saved_text === 'original OpenClaw answer');

    expect(savedReplyState).toBeDefined();
    expect(patchMessage).toHaveBeenCalledWith(
      'assistant_message_saved_text',
      expect.objectContaining({
        text: 'original OpenClaw answer',
      }),
    );
  });
});
