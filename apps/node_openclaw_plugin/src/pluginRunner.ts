import { setTimeout as sleep } from 'node:timers/promises';
import { PlatformClient, PlatformHttpError } from './platformClient.js';
import { DEFAULT_MAX_PROCESSED_EVENTS, FileStateStore } from './stateStore.js';
import type {
  CreateMessageRequest,
  PlatformEvent,
  PluginPersistentState,
  PluginRuntimeConfig,
} from './types.js';

export class NodeOpenClawPluginRunner {
  private readonly client: PlatformClient;
  private readonly stateStore: FileStateStore;
  private state: PluginPersistentState;

  constructor(private readonly config: PluginRuntimeConfig) {
    this.client = new PlatformClient(config.baseUrl, config.token, config.pluginId);
    this.stateStore = new FileStateStore(config.stateFilePath, config.defaultCursor);
    this.state = {
      cursor: config.defaultCursor,
      processedEventIds: [],
      clientTokenMessageMap: {},
      pendingAck: null,
    };
  }

  async runForever(): Promise<void> {
    this.state = await this.stateStore.load();
    console.log('[node_openclaw_plugin] started with cursor:', this.state.cursor);

    for (;;) {
      try {
        await this.tick();
      } catch (error) {
        console.error('[node_openclaw_plugin] tick failed:', error);
      }
      await sleep(this.config.pollIntervalMs);
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
        console.log('[node_openclaw_plugin] binding_changed received', {
          eventId: event.eventId,
          conversationId: event.conversationId,
        });
        return;
      default:
        console.log('[node_openclaw_plugin] ignored event type', {
          eventId: event.eventId,
          eventType: event.eventType,
        });
    }
  }

  private async handleMessageCreated(event: PlatformEvent): Promise<void> {
    if (!event.conversationId && !event.rawId) {
      console.warn('[node_openclaw_plugin] skip event without conversation identity', event.eventId);
      return;
    }
    if (!shouldProcessEvent(event, this.config.tokenUserId)) {
      return;
    }

    const topology = await this.client.resolveConversation({
      conversationId: event.conversationId,
      rawId: event.rawId,
    });

    const inputText = extractIncomingText(event.payload);
    const responseText = `收到消息：${inputText}`;
    const clientToken = `evt:${event.eventId}`;

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

    if (!messageId) {
      const created = await this.client.createMessage(createPayload);
      messageId = created.messageId;
      this.state.clientTokenMessageMap[clientToken] = messageId;
    }

    try {
      await this.client.patchMessage(messageId, {
        text: responseText,
        metadata: {
          sourceEventId: event.eventId,
          handledBy: this.config.assistantName,
        },
      });
    } catch (error) {
      if (error instanceof PlatformHttpError && error.status === 409) {
        console.warn('[node_openclaw_plugin] revision conflict; skipped patch', { messageId, eventId: event.eventId });
        return;
      }
      throw error;
    }
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

export function shouldProcessEvent(event: PlatformEvent, tokenUserId: string): boolean {
  void tokenUserId;
  if (event.eventType !== 'message.created') {
    return true;
  }

  const sender = event.payload?.sender;
  if (!sender) return true;

  if (sender.displayName && ['assistant', 'system'].includes(sender.displayName.toLowerCase())) {
    return false;
  }

  return true;
}
