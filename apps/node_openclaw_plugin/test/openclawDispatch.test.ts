import { describe, expect, it, vi } from 'vitest';
import {
  buildBricksConversationLabel,
  dispatchBricksInboundMessage,
  normalizeBricksThreadId,
} from '../src/openclawDispatch.js';
import type { PlatformEvent, ResolveConversationResponse } from '../src/types.js';
import type { OutboundReplyPayload } from 'openclaw/plugin-sdk/reply-payload';

const baseTopology: ResolveConversationResponse = {
  conversationId: 'session:general:main',
  channelId: 'general',
  threadId: 'main',
};

const baseEvent: PlatformEvent = {
  eventId: 'evt_1',
  eventType: 'message.created',
  workspaceId: 'ws_1',
  conversationId: 'session:general:main',
  occurredAt: '2026-04-20T12:34:56.000Z',
  payload: {
    text: 'hello',
    messageId: 'msg_user_1',
    sender: {
      userId: 'user_1',
      displayName: 'Alice',
    },
  },
};

describe('normalizeBricksThreadId', () => {
  it('treats blank and main as the base channel session', () => {
    expect(normalizeBricksThreadId()).toBeUndefined();
    expect(normalizeBricksThreadId('')).toBeUndefined();
    expect(normalizeBricksThreadId('main')).toBeUndefined();
  });

  it('keeps non-main thread ids', () => {
    expect(normalizeBricksThreadId('thread-7')).toBe('thread-7');
  });
});

describe('buildBricksConversationLabel', () => {
  it('includes thread information only for non-main threads', () => {
    expect(buildBricksConversationLabel(baseTopology)).toBe('Bricks channel general');
    expect(
      buildBricksConversationLabel({
        ...baseTopology,
        threadId: 'thread-7',
      }),
    ).toBe('Bricks channel general thread thread-7');
  });
});

describe('dispatchBricksInboundMessage', () => {
  it('routes thread conversations to thread-suffixed OpenClaw sessions', async () => {
    const deliver = vi.fn<(payload: OutboundReplyPayload) => Promise<void>>().mockResolvedValue();
    const finalizeInboundContext = vi.fn((ctx) => ({ ...ctx, CommandAuthorized: false }));
    const recordInboundSessionAndDispatchReply = vi.fn(async (params) => {
      await params.deliver({ text: 'OpenClaw reply' });
    });

    const result = await dispatchBricksInboundMessage(
      {
        accountId: 'user-1',
        topology: {
          ...baseTopology,
          conversationId: 'session:general:thread-7',
          threadId: 'thread-7',
        },
        event: baseEvent,
        rawBody: 'hello',
        abortSignal: new AbortController().signal,
        deliver,
      },
      {
        loadConfig: async () => ({ session: { store: 'sessions' } }),
        resolveAgentRoute: vi.fn(() => ({
          agentId: 'main',
          accountId: 'user-1',
          sessionKey: 'agent:main:dev-askman-bricks:channel:general',
        })),
        resolveThreadSessionKeys: vi.fn(() => ({
          sessionKey: 'agent:main:dev-askman-bricks:channel:general:thread:thread-7',
          parentSessionKey: 'agent:main:dev-askman-bricks:channel:general',
        })),
        createInboundEnvelopeBuilder: vi.fn(() => () => ({
          storePath: '/tmp/openclaw-sessions',
          body: 'ENVELOPE: hello',
        })),
        resolveStorePath: vi.fn(() => '/tmp/openclaw-sessions'),
        readSessionUpdatedAt: vi.fn(() => undefined),
        resolveEnvelopeFormatOptions: vi.fn(() => ({})),
        formatInboundEnvelope: vi.fn(() => 'ENVELOPE: hello'),
        finalizeInboundContext,
        recordInboundSessionAndDispatchReply,
      },
    );

    expect(result).toEqual({
      agentId: 'main',
      sessionKey: 'agent:main:dev-askman-bricks:channel:general:thread:thread-7',
      storePath: '/tmp/openclaw-sessions',
    });
    expect(finalizeInboundContext).toHaveBeenCalledWith(
      expect.objectContaining({
        Body: 'ENVELOPE: hello',
        BodyForAgent: 'hello',
        RawBody: 'hello',
        SessionKey: 'agent:main:dev-askman-bricks:channel:general:thread:thread-7',
        ParentSessionKey: 'agent:main:dev-askman-bricks:channel:general',
        ConversationLabel: 'Bricks channel general thread thread-7',
        NativeChannelId: 'general',
        ThreadLabel: 'thread-7',
        MessageThreadId: 'thread-7',
        MessageSid: 'msg_user_1',
        OriginatingChannel: 'dev-askman-bricks',
        OriginatingTo: 'session:general:thread-7',
        ExplicitDeliverRoute: true,
      }),
    );
    expect(recordInboundSessionAndDispatchReply).toHaveBeenCalledWith(
      expect.objectContaining({
        routeSessionKey: 'agent:main:dev-askman-bricks:channel:general:thread:thread-7',
        agentId: 'main',
        storePath: '/tmp/openclaw-sessions',
        replyOptions: expect.objectContaining({
          abortSignal: expect.any(AbortSignal),
        }),
      }),
    );
    expect(deliver).toHaveBeenCalledWith({ text: 'OpenClaw reply' });
  });

  it('keeps main-thread conversations on the base session key', async () => {
    const finalizeInboundContext = vi.fn((ctx) => ({ ...ctx, CommandAuthorized: false }));

    await dispatchBricksInboundMessage(
      {
        accountId: 'user-1',
        topology: baseTopology,
        event: baseEvent,
        rawBody: 'hello',
        abortSignal: new AbortController().signal,
        deliver: vi.fn().mockResolvedValue(undefined),
      },
      {
        loadConfig: async () => ({ session: { store: 'sessions' } }),
        resolveAgentRoute: vi.fn(() => ({
          agentId: 'main',
          accountId: 'user-1',
          sessionKey: 'agent:main:dev-askman-bricks:channel:general',
        })),
        resolveThreadSessionKeys: vi.fn((params) => ({
          sessionKey: params.baseSessionKey,
          parentSessionKey: undefined,
        })),
        createInboundEnvelopeBuilder: vi.fn(() => () => ({
          storePath: '/tmp/openclaw-sessions',
          body: 'ENVELOPE: hello',
        })),
        resolveStorePath: vi.fn(() => '/tmp/openclaw-sessions'),
        readSessionUpdatedAt: vi.fn(() => undefined),
        resolveEnvelopeFormatOptions: vi.fn(() => ({})),
        formatInboundEnvelope: vi.fn(() => 'ENVELOPE: hello'),
        finalizeInboundContext,
        recordInboundSessionAndDispatchReply: vi.fn(async () => {}),
      },
    );

    expect(finalizeInboundContext).toHaveBeenCalledWith(
      expect.objectContaining({
        SessionKey: 'agent:main:dev-askman-bricks:channel:general',
        ParentSessionKey: undefined,
        ThreadLabel: undefined,
        MessageThreadId: undefined,
      }),
    );
  });

  it('rethrows dispatch errors surfaced only through callbacks', async () => {
    await expect(
      dispatchBricksInboundMessage(
        {
          accountId: 'user-1',
          topology: baseTopology,
          event: baseEvent,
          rawBody: 'hello',
          abortSignal: new AbortController().signal,
          deliver: vi.fn().mockResolvedValue(undefined),
        },
        {
          loadConfig: async () => ({ session: { store: 'sessions' } }),
          resolveAgentRoute: vi.fn(() => ({
            agentId: 'main',
            accountId: 'user-1',
            sessionKey: 'agent:main:dev-askman-bricks:channel:general',
          })),
          resolveThreadSessionKeys: vi.fn((params) => ({
            sessionKey: params.baseSessionKey,
            parentSessionKey: undefined,
          })),
          createInboundEnvelopeBuilder: vi.fn(() => () => ({
            storePath: '/tmp/openclaw-sessions',
            body: 'ENVELOPE: hello',
          })),
          resolveStorePath: vi.fn(() => '/tmp/openclaw-sessions'),
          readSessionUpdatedAt: vi.fn(() => undefined),
          resolveEnvelopeFormatOptions: vi.fn(() => ({})),
          formatInboundEnvelope: vi.fn(() => 'ENVELOPE: hello'),
          finalizeInboundContext: vi.fn((ctx) => ({ ...ctx, CommandAuthorized: false })),
          recordInboundSessionAndDispatchReply: vi.fn(async (dispatchParams) => {
            dispatchParams.onDispatchError(new Error('boom'), { kind: 'deliver' });
          }),
        },
      ),
    ).rejects.toThrow('OpenClaw dispatch failed during deliver');
  });

  it('fails fast when already aborted before dispatch starts', async () => {
    const abortController = new AbortController();
    abortController.abort();

    await expect(
      dispatchBricksInboundMessage(
        {
          accountId: 'user-1',
          topology: baseTopology,
          event: baseEvent,
          rawBody: 'hello',
          abortSignal: abortController.signal,
          deliver: vi.fn().mockResolvedValue(undefined),
        },
        {
          loadConfig: vi.fn(async () => ({ session: { store: 'sessions' } })),
          resolveAgentRoute: vi.fn(),
          resolveThreadSessionKeys: vi.fn(),
          createInboundEnvelopeBuilder: vi.fn(),
          resolveStorePath: vi.fn(),
          readSessionUpdatedAt: vi.fn(),
          resolveEnvelopeFormatOptions: vi.fn(),
          formatInboundEnvelope: vi.fn(),
          finalizeInboundContext: vi.fn(),
          recordInboundSessionAndDispatchReply: vi.fn(),
        },
      ),
    ).rejects.toMatchObject({ name: 'AbortError' });
  });
});
