import {
  loadConfig,
  readSessionUpdatedAt,
  resolveStorePath,
  type OpenClawConfig,
} from 'openclaw/plugin-sdk/config-runtime';
import { recordInboundSession } from 'openclaw/plugin-sdk/conversation-runtime';
import { createInboundEnvelopeBuilder } from 'openclaw/plugin-sdk/inbound-envelope';
import { recordInboundSessionAndDispatchReply } from 'openclaw/plugin-sdk/inbound-reply-dispatch';
import {
  resolveAgentRoute,
  resolveThreadSessionKeys,
  type ResolvedAgentRoute,
  type RoutePeer,
} from 'openclaw/plugin-sdk/routing';
import {
  formatInboundEnvelope,
  resolveEnvelopeFormatOptions,
} from 'openclaw/plugin-sdk/channel-inbound';
import {
  dispatchReplyWithBufferedBlockDispatcher,
  finalizeInboundContext,
} from 'openclaw/plugin-sdk/reply-dispatch-runtime';
import type { OutboundReplyPayload } from 'openclaw/plugin-sdk/reply-payload';
import { CHANNEL_ID, CHANNEL_NAME } from './channelConstants.js';
import type { PlatformEvent, ResolveConversationResponse } from './types.js';

export interface BricksInboundDispatchParams {
  accountId: string;
  topology: ResolveConversationResponse;
  event: PlatformEvent;
  rawBody: string;
  abortSignal?: AbortSignal;
  deliver: (payload: OutboundReplyPayload) => Promise<void>;
}

export interface BricksInboundDispatchResult {
  agentId: string;
  sessionKey: string;
  storePath: string;
}

export interface OpenClawDispatchDeps {
  loadConfig: () => OpenClawConfig | Promise<OpenClawConfig>;
  resolveAgentRoute: (params: {
    cfg: OpenClawConfig;
    channel: string;
    accountId: string;
    peer: RoutePeer;
  }) => ResolvedAgentRoute;
  resolveThreadSessionKeys: typeof resolveThreadSessionKeys;
  createInboundEnvelopeBuilder: typeof createInboundEnvelopeBuilder;
  resolveStorePath: typeof resolveStorePath;
  readSessionUpdatedAt: typeof readSessionUpdatedAt;
  resolveEnvelopeFormatOptions: typeof resolveEnvelopeFormatOptions;
  formatInboundEnvelope: typeof formatInboundEnvelope;
  finalizeInboundContext: typeof finalizeInboundContext;
  recordInboundSessionAndDispatchReply: typeof recordInboundSessionAndDispatchReply;
}

export const defaultOpenClawDispatchDeps: OpenClawDispatchDeps = {
  loadConfig,
  resolveAgentRoute,
  resolveThreadSessionKeys,
  createInboundEnvelopeBuilder,
  resolveStorePath,
  readSessionUpdatedAt,
  resolveEnvelopeFormatOptions,
  formatInboundEnvelope,
  finalizeInboundContext,
  recordInboundSessionAndDispatchReply,
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function normalizeBricksThreadId(threadId?: string): string | undefined {
  const trimmed = threadId?.trim();
  if (!trimmed || trimmed === 'main') {
    return undefined;
  }
  return trimmed;
}

export function buildBricksConversationLabel(topology: ResolveConversationResponse): string {
  const threadId = normalizeBricksThreadId(topology.threadId);
  return threadId
    ? `Bricks channel ${topology.channelId} thread ${threadId}`
    : `Bricks channel ${topology.channelId}`;
}

export function buildBricksPeer(topology: ResolveConversationResponse): RoutePeer {
  return {
    kind: 'channel',
    id: topology.channelId,
  };
}

export function resolveEventMessageId(event: PlatformEvent): string {
  const payloadMessageId = event.payload && isRecord(event.payload)
    ? event.payload.messageId
    : undefined;
  if (typeof payloadMessageId === 'string' && payloadMessageId.trim().length > 0) {
    return payloadMessageId.trim();
  }
  return event.eventId;
}

export function parseEventTimestamp(occurredAt?: string): number | undefined {
  if (!occurredAt) {
    return undefined;
  }
  const parsed = Date.parse(occurredAt);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function buildSenderAddress(event: PlatformEvent): string {
  const senderId = event.payload?.sender?.userId?.trim();
  return senderId ? `bricks:user:${senderId}` : 'bricks:user:unknown';
}

function buildRecipientAddress(topology: ResolveConversationResponse): string {
  return `bricks:conversation:${topology.conversationId}`;
}

function buildUntrustedContext(
  event: PlatformEvent,
  topology: ResolveConversationResponse,
): string[] {
  const context = [
    `Bricks conversationId: ${topology.conversationId}`,
    `Bricks channelId: ${topology.channelId}`,
  ];
  if (event.workspaceId?.trim()) {
    context.push(`Bricks workspaceId: ${event.workspaceId.trim()}`);
  }
  const threadId = normalizeBricksThreadId(topology.threadId);
  if (threadId) {
    context.push(`Bricks threadId: ${threadId}`);
  }
  if (topology.rawId?.trim()) {
    context.push(`Bricks rawId: ${topology.rawId.trim()}`);
  }
  return context;
}

function wrapDispatchError(error: unknown, info: { kind: string }): Error {
  const cause = error instanceof Error ? error : new Error(String(error));
  return new Error(`OpenClaw dispatch failed during ${info.kind}`, { cause });
}

function wrapRecordError(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }
  return new Error(String(error));
}

function createAbortError(): Error {
  const error = new Error('Aborted');
  error.name = 'AbortError';
  return error;
}

function throwIfAborted(abortSignal?: AbortSignal): void {
  if (abortSignal?.aborted) {
    throw createAbortError();
  }
}

export async function dispatchBricksInboundMessage(
  params: BricksInboundDispatchParams,
  deps: OpenClawDispatchDeps = defaultOpenClawDispatchDeps,
): Promise<BricksInboundDispatchResult> {
  throwIfAborted(params.abortSignal);
  const cfg = await deps.loadConfig();
  throwIfAborted(params.abortSignal);
  const route = deps.resolveAgentRoute({
    cfg,
    channel: CHANNEL_ID,
    accountId: params.accountId,
    peer: buildBricksPeer(params.topology),
  });

  const threadId = normalizeBricksThreadId(params.topology.threadId);
  const threadRoute = deps.resolveThreadSessionKeys({
    baseSessionKey: route.sessionKey,
    threadId,
    parentSessionKey: threadId ? route.sessionKey : undefined,
  });

  const buildEnvelope = deps.createInboundEnvelopeBuilder({
    cfg,
    route: {
      agentId: route.agentId,
      sessionKey: threadRoute.sessionKey,
    },
    sessionStore: cfg.session?.store,
    resolveStorePath: deps.resolveStorePath,
    readSessionUpdatedAt: deps.readSessionUpdatedAt,
    resolveEnvelopeFormatOptions: deps.resolveEnvelopeFormatOptions,
    formatAgentEnvelope: deps.formatInboundEnvelope,
  });

  const timestamp = parseEventTimestamp(params.event.occurredAt);
  const conversationLabel = buildBricksConversationLabel(params.topology);
  const { body, storePath } = buildEnvelope({
    channel: CHANNEL_NAME,
    from: conversationLabel,
    body: params.rawBody,
    timestamp,
  });
  throwIfAborted(params.abortSignal);

  const sender = params.event.payload?.sender;
  const messageId = resolveEventMessageId(params.event);
  const ctxPayload = deps.finalizeInboundContext({
    Body: body,
    BodyForAgent: params.rawBody,
    RawBody: params.rawBody,
    CommandBody: params.rawBody,
    From: buildSenderAddress(params.event),
    To: buildRecipientAddress(params.topology),
    SessionKey: threadRoute.sessionKey,
    ParentSessionKey: threadRoute.parentSessionKey,
    AccountId: route.accountId ?? params.accountId,
    MessageSid: messageId,
    MessageSidFull: messageId,
    Timestamp: timestamp,
    CommandAuthorized: false,
    Provider: CHANNEL_ID,
    Surface: CHANNEL_ID,
    ChatType: 'channel',
    ConversationLabel: conversationLabel,
    GroupChannel: params.topology.channelId,
    ThreadLabel: threadId,
    MessageThreadId: threadId,
    ThreadParentId: threadId ? params.topology.channelId : undefined,
    NativeChannelId: params.topology.channelId,
    SenderId: sender?.userId,
    SenderName: sender?.displayName,
    OriginatingChannel: CHANNEL_ID,
    OriginatingTo: params.topology.rawId ?? params.topology.conversationId,
    ExplicitDeliverRoute: true,
    UntrustedContext: buildUntrustedContext(params.event, params.topology),
  });

  let recordFailure: Error | null = null;
  let dispatchFailure: Error | null = null;

  await deps.recordInboundSessionAndDispatchReply({
    cfg,
    channel: CHANNEL_ID,
    accountId: route.accountId ?? params.accountId,
    agentId: route.agentId,
    routeSessionKey: threadRoute.sessionKey,
    storePath,
    ctxPayload,
    recordInboundSession,
    dispatchReplyWithBufferedBlockDispatcher,
    deliver: params.deliver,
    onRecordError: (error) => {
      recordFailure ??= wrapRecordError(error);
    },
    onDispatchError: (error, info) => {
      dispatchFailure ??= wrapDispatchError(error, info);
    },
    replyOptions: params.abortSignal
      ? {
          abortSignal: params.abortSignal,
        }
      : undefined,
  });

  if (recordFailure) {
    throw recordFailure;
  }
  if (dispatchFailure) {
    throw dispatchFailure;
  }

  return {
    agentId: route.agentId,
    sessionKey: threadRoute.sessionKey,
    storePath,
  };
}
