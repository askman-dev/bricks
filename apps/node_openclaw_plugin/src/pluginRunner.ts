import { setTimeout as sleep } from 'node:timers/promises';
import type { OutboundReplyPayload } from 'openclaw/plugin-sdk/reply-payload';
import { dispatchBricksInboundMessage } from './openclawDispatch.js';
import { PlatformClient, PlatformHttpError } from './platformClient.js';
import { DEFAULT_MAX_PROCESSED_EVENTS, FileStateStore } from './stateStore.js';
import type {
  CreateMessageResponse,
  CreateMessageRequest,
  GetEventsResponse,
  PatchMessageRequest,
  PlatformEvent,
  PluginPersistentState,
  PluginRuntimeConfig,
  ResolveConversationResponse,
  RunnerLogSink,
} from './types.js';

interface PlatformClientLike {
  getEvents(cursor: string, limit?: number): Promise<GetEventsResponse>;
  ackEvents(cursor: string, ackedEventIds: string[]): Promise<{ ok: boolean }>;
  resolveConversation(args: {
    conversationId?: string;
    rawId?: string;
  }): Promise<ResolveConversationResponse>;
  createMessage(payload: CreateMessageRequest): Promise<CreateMessageResponse>;
  patchMessage(messageId: string, payload: PatchMessageRequest): Promise<{ ok: boolean }>;
}

interface StateStoreLike {
  load(): Promise<PluginPersistentState>;
  save(state: PluginPersistentState): Promise<void>;
}

interface NodeOpenClawPluginRunnerDeps {
  client?: PlatformClientLike;
  stateStore?: StateStoreLike;
  dispatchBricksInboundMessage?: typeof dispatchBricksInboundMessage;
  log?: RunnerLogSink;
}

const defaultRunnerLog: RunnerLogSink = {
  info: (message) => console.log(message),
  warn: (message) => console.warn(message),
  error: (message) => console.error(message),
};

const RETRYABLE_NETWORK_ERROR_CODES = new Set([
  'EAI_AGAIN',
  'ECONNREFUSED',
  'ECONNRESET',
  'ENETUNREACH',
  'ENOTFOUND',
  'EHOSTUNREACH',
  'ETIMEDOUT',
  'UND_ERR_CONNECT_TIMEOUT',
]);

export class NodeOpenClawPluginRunner {
  private readonly client: PlatformClientLike;
  private readonly stateStore: StateStoreLike;
  private readonly dispatchBricksInboundMessage: typeof dispatchBricksInboundMessage;
  private readonly log: RunnerLogSink;
  private abortSignal?: AbortSignal;
  private nextPollDelayMs: number;
  private state: PluginPersistentState;

  constructor(
    private readonly config: PluginRuntimeConfig,
    deps: NodeOpenClawPluginRunnerDeps = {},
  ) {
    this.log = deps.log ?? defaultRunnerLog;
    this.client = deps.client
      ?? new PlatformClient(
        config.baseUrl,
        config.token,
        config.pluginId,
        () => this.abortSignal,
      );
    this.stateStore = deps.stateStore
      ?? new FileStateStore(config.stateFilePath, config.defaultCursor);
    this.dispatchBricksInboundMessage = deps.dispatchBricksInboundMessage
      ?? dispatchBricksInboundMessage;
    this.state = {
      cursor: config.defaultCursor,
      processedEventIds: [],
      clientTokenMessageMap: {},
      clientTokenReplyTextMap: {},
      pendingAck: null,
    };
    this.nextPollDelayMs = config.pollIntervalMs;
  }

  async runForever(): Promise<void> {
    await this.runUntilAbort();
  }

  async runUntilAbort(abortSignal?: AbortSignal): Promise<void> {
    this.abortSignal = abortSignal;
    this.state = await this.stateStore.load();
    this.log.info(`[node_openclaw_plugin] started with cursor: ${this.state.cursor}`);

    try {
      while (!abortSignal?.aborted) {
        try {
          await this.tick();
          this.nextPollDelayMs = this.config.pollIntervalMs;
        } catch (error) {
          if (abortSignal?.aborted || isAbortError(error)) {
            break;
          }
          const retryDelayMs = resolveRetryDelayMs(error, this.nextPollDelayMs, this.config.pollIntervalMs);
          if (retryDelayMs !== null) {
            this.nextPollDelayMs = retryDelayMs;
            this.log.warn(
              `[node_openclaw_plugin] retryable platform/network failure; backing off for ${retryDelayMs}ms: ${formatRunnerError(error)}`,
            );
          } else {
            this.log.error(`[node_openclaw_plugin] tick failed: ${formatRunnerError(error)}`);
            this.nextPollDelayMs = this.config.pollIntervalMs;
          }
        }
        await sleepUntilNextTick(this.nextPollDelayMs, abortSignal);
      }
    } finally {
      this.abortSignal = undefined;
      if (abortSignal?.aborted) {
        this.log.info('[node_openclaw_plugin] stopped');
      }
    }
  }

  async tick(): Promise<void> {
    await this.flushPendingAck();

    const response = await this.client.getEvents(this.state.cursor, 50);
    const receivedEventIds = response.events
      .map((event) => event.eventId)
      .filter((eventId) => eventId.trim().length > 0);

    for (const event of response.events) {
      if (this.state.processedEventIds.includes(event.eventId)) {
        continue;
      }

      await this.handleEvent(event);
      this.state.processedEventIds.push(event.eventId);
    }

    // Keep in-memory array bounded to prevent unbounded growth during long runs
    this.state.processedEventIds = this.state.processedEventIds.slice(-DEFAULT_MAX_PROCESSED_EVENTS);

    if (receivedEventIds.length > 0) {
      this.state.pendingAck = {
        cursor: response.nextCursor,
        eventIds: receivedEventIds,
      };
      await this.stateStore.save(this.state);
      await this.flushPendingAck();
      return;
    }

    this.state.cursor = response.nextCursor;
    await this.stateStore.save(this.state);
  }

  private async flushPendingAck(): Promise<void> {
    if (!this.state.pendingAck) {
      return;
    }

    await this.client.ackEvents(this.state.pendingAck.cursor, this.state.pendingAck.eventIds);
    this.state.cursor = this.state.pendingAck.cursor;
    this.state.pendingAck = null;
    await this.stateStore.save(this.state);
  }

  private async handleEvent(event: PlatformEvent): Promise<void> {
    switch (event.eventType) {
      case 'message.created':
        await this.handleMessageCreated(event);
        return;
      case 'conversation.binding_changed':
        this.log.info(
          `[node_openclaw_plugin] binding_changed received eventId=${event.eventId} conversationId=${event.conversationId ?? 'unknown'}`,
        );
        return;
      default:
        this.log.info(
          `[node_openclaw_plugin] ignored event type eventId=${event.eventId} eventType=${event.eventType}`,
        );
    }
  }

  private async handleMessageCreated(event: PlatformEvent): Promise<void> {
    if (!event.conversationId && !event.rawId) {
      this.log.warn(`[node_openclaw_plugin] skip event without conversation identity ${event.eventId}`);
      return;
    }
    if (!shouldProcessEvent(event)) {
      return;
    }

    const topology = await this.client.resolveConversation({
      conversationId: event.conversationId,
      rawId: event.rawId,
    });

    const inputText = extractIncomingText(event.payload);
    const clientToken = assistantClientTokenForEvent(event);

    const createPayload: CreateMessageRequest = {
      workspaceId: event.workspaceId,
      conversationId: topology.conversationId,
      channelId: topology.channelId,
      threadId: topology.threadId,
      role: 'assistant',
      status: 'streaming',
      text: `${this.config.assistantName} 正在处理...`,
      clientToken,
      metadata: {
        sourceEventId: event.eventId,
        plugin: 'node_openclaw_plugin',
      },
    };

    let messageId = this.state.clientTokenMessageMap[clientToken];
    const reusedExistingMessage = Boolean(messageId);

    if (!messageId) {
      const created = await this.client.createMessage(createPayload);
      messageId = created.messageId;
      this.state.clientTokenMessageMap[clientToken] = messageId;
      await this.stateStore.save(this.state);
    }

    let accumulatedReplyText = this.state.clientTokenReplyTextMap[clientToken] ?? '';
    let visibleReplyCount = 0;

    const dispatchResult = await this.dispatchBricksInboundMessage({
      accountId: this.config.tokenUserId,
      topology,
      event,
      rawBody: inputText,
      abortSignal: this.abortSignal,
      deliver: async (payload) => {
        const replyText = extractReplyText(payload);
        if (!replyText) {
          return;
        }
        visibleReplyCount += 1;
        accumulatedReplyText = appendReplyText(accumulatedReplyText, replyText);
        await this.rememberPatchedReplyText(clientToken, accumulatedReplyText);
        await this.patchAssistantMessage(messageId, event.eventId, accumulatedReplyText);
      },
    });

    if (visibleReplyCount === 0) {
      const fallbackText = accumulatedReplyText || buildNoVisibleReplyText(this.config.assistantName);
      await this.patchAssistantMessage(messageId, event.eventId, fallbackText, {
        openclawAgentId: dispatchResult.agentId,
        openclawSessionKey: dispatchResult.sessionKey,
        openclawStatus: 'no_visible_reply',
        openclawReusedPlaceholder: reusedExistingMessage,
      });
      await this.rememberPatchedReplyText(clientToken, fallbackText);
      this.log.warn(
        `[node_openclaw_plugin] OpenClaw produced no visible reply; finalized placeholder messageId=${messageId} eventId=${event.eventId} reusedPlaceholder=${reusedExistingMessage}`,
      );
      return;
    }

    await this.patchAssistantMessage(messageId, event.eventId, accumulatedReplyText, {
      openclawAgentId: dispatchResult.agentId,
      openclawSessionKey: dispatchResult.sessionKey,
    });
    await this.rememberPatchedReplyText(clientToken, accumulatedReplyText);
  }

  private async patchAssistantMessage(
    messageId: string,
    eventId: string,
    text: string,
    extraMetadata?: Record<string, unknown>,
  ): Promise<void> {
    try {
      await this.client.patchMessage(messageId, {
        text,
        metadata: {
          sourceEventId: eventId,
          plugin: 'node_openclaw_plugin',
          handledBy: this.config.assistantName,
          ...extraMetadata,
        },
      });
    } catch (error) {
      if (error instanceof PlatformHttpError && error.status === 409) {
        this.log.warn(
          `[node_openclaw_plugin] revision conflict; skipped patch messageId=${messageId} eventId=${eventId}`,
        );
        return;
      }
      throw error;
    }
  }

  private async rememberPatchedReplyText(clientToken: string, text: string): Promise<void> {
    const normalized = text.trim();
    if (!normalized) {
      return;
    }
    if (this.state.clientTokenReplyTextMap[clientToken] === normalized) {
      return;
    }
    this.state.clientTokenReplyTextMap[clientToken] = normalized;
    await this.stateStore.save(this.state);
  }
}

export function extractIncomingText(payload?: PlatformEvent['payload']): string {
  const text = payload?.text;
  if (typeof text === 'string' && text.trim().length > 0) {
    return text.trim();
  }

  const nestedText = payload?.content;
  if (typeof nestedText === 'string' && nestedText.trim().length > 0) {
    return nestedText.trim();
  }

  return '[empty message]';
}

export function shouldProcessEvent(event: PlatformEvent): boolean {
  if (event.eventType !== 'message.created') {
    return true;
  }

  const metadata = event.payload?.metadata;
  if (
    metadata &&
    typeof metadata === 'object' &&
    !Array.isArray(metadata) &&
    (metadata as Record<string, unknown>).plugin === 'node_openclaw_plugin'
  ) {
    return false;
  }

  const sender = event.payload?.sender;
  if (!sender) return true;

  if (sender.displayName && ['assistant', 'system'].includes(sender.displayName.toLowerCase())) {
    return false;
  }

  return true;
}

export function assistantClientTokenForEvent(event: PlatformEvent): string {
  const metadata = event.payload?.metadata;
  if (metadata && typeof metadata === 'object' && !Array.isArray(metadata)) {
    const pendingAssistantMessageId =
        (metadata as Record<string, unknown>)['pendingAssistantMessageId'];
    if (
      typeof pendingAssistantMessageId === 'string' &&
      pendingAssistantMessageId.trim().length > 0
    ) {
      return pendingAssistantMessageId.trim();
    }
  }

  return `evt:${event.eventId}`;
}

function collectMediaUrls(payload: OutboundReplyPayload): string[] {
  const urls = [...(payload.mediaUrls ?? [])];
  if (typeof payload.mediaUrl === 'string' && payload.mediaUrl.trim().length > 0) {
    urls.push(payload.mediaUrl.trim());
  }
  return urls.filter((value, index, all) => value.trim().length > 0 && all.indexOf(value) === index);
}

export function extractReplyText(payload: OutboundReplyPayload): string {
  const text = typeof payload.text === 'string' ? payload.text.trim() : '';
  const mediaUrls = collectMediaUrls(payload);
  if (mediaUrls.length === 0) {
    return text;
  }
  return text ? `${text}\n\n${mediaUrls.join('\n')}` : mediaUrls.join('\n');
}

export function appendReplyText(existing: string, incoming: string): string {
  const next = incoming.trim();
  if (!next) {
    return existing;
  }
  if (!existing) {
    return next;
  }
  if (existing === next || existing.endsWith(`\n\n${next}`)) {
    return existing;
  }
  return `${existing}\n\n${next}`;
}

export function buildNoVisibleReplyText(assistantName: string): string {
  return `${assistantName} 当前没有返回可显示的回复，请稍后重试。`;
}

function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === 'AbortError';
}

export function shouldBackoffPlatformError(error: unknown): error is PlatformHttpError {
  return error instanceof PlatformHttpError
    && (
      error.status === 429
      || error.retryable === true
      || error.status >= 500
    );
}

export function shouldBackoffRunnerError(error: unknown): boolean {
  if (error instanceof PlatformHttpError) {
    return error.status === 429
      || error.retryable === true
      || error.status >= 500;
  }

  return hasRetryableNetworkCause(error);
}

export function nextBackoffDelayMs(
  currentDelayMs: number,
  baseDelayMs: number,
  capDelayMs = 10_000,
): number {
  if (currentDelayMs > capDelayMs) {
    return currentDelayMs;
  }

  const effectiveBase = Math.min(Math.max(baseDelayMs, 1), capDelayMs);
  const effectiveCurrent = Math.max(currentDelayMs, effectiveBase);
  const steppedDelay = effectiveCurrent <= effectiveBase
    ? effectiveBase * 2
    : effectiveCurrent * 2;

  return Math.min(capDelayMs, steppedDelay);
}

export function resolveRetryDelayMs(
  error: unknown,
  currentDelayMs: number,
  baseDelayMs: number,
  capDelayMs = 10_000,
): number | null {
  if (!shouldBackoffRunnerError(error)) {
    return null;
  }

  if (
    error instanceof PlatformHttpError
    && typeof error.retryAfterMs === 'number'
    && Number.isFinite(error.retryAfterMs)
    && error.retryAfterMs > 0
  ) {
    return Math.max(baseDelayMs, error.retryAfterMs);
  }

  return nextBackoffDelayMs(currentDelayMs, baseDelayMs, capDelayMs);
}

function formatRunnerError(error: unknown): string {
  if (error instanceof Error) {
    return formatErrorChain(error);
  }
  return String(error);
}

function formatErrorChain(error: Error): string {
  const parts: string[] = [];
  const seen = new Set<unknown>();
  let current: unknown = error;

  while (current instanceof Error && !seen.has(current)) {
    seen.add(current);
    parts.push(current.stack ?? `${current.name}: ${current.message}`);
    current = (current as Error & { cause?: unknown }).cause;
  }

  return parts.join('\nCaused by: ');
}

function hasRetryableNetworkCause(error: unknown): boolean {
  const seen = new Set<unknown>();
  let current: unknown = error;

  while (current && typeof current === 'object' && !seen.has(current)) {
    seen.add(current);
    const candidate = current as {
      code?: unknown;
      name?: unknown;
      message?: unknown;
      cause?: unknown;
    };

    if (typeof candidate.code === 'string' && RETRYABLE_NETWORK_ERROR_CODES.has(candidate.code)) {
      return true;
    }

    if (candidate.name === 'TypeError' && candidate.message === 'fetch failed') {
      return true;
    }

    current = candidate.cause;
  }

  return false;
}

async function sleepUntilNextTick(delayMs: number, abortSignal?: AbortSignal): Promise<void> {
  if (!abortSignal) {
    await sleep(delayMs);
    return;
  }
  if (abortSignal.aborted) {
    return;
  }

  await new Promise<void>((resolve) => {
    const timer = setTimeout(() => {
      cleanup();
      resolve();
    }, delayMs);

    const onAbort = () => {
      cleanup();
      resolve();
    };

    const cleanup = () => {
      clearTimeout(timer);
      abortSignal.removeEventListener('abort', onAbort);
    };

    abortSignal.addEventListener('abort', onAbort, { once: true });
  });
}
