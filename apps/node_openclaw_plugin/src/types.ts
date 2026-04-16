export type PlatformEventType = 'message.created' | 'interaction.submitted' | 'conversation.binding_changed' | string;

export interface PlatformEvent {
  eventId: string;
  eventType: PlatformEventType;
  workspaceId?: string;
  conversationId?: string;
  rawId?: string;
  occurredAt?: string;
  payload?: {
    text?: string;
    content?: string;
    sender?: {
      userId?: string;
      displayName?: string;
    };
    [key: string]: unknown;
  };
}

export interface GetEventsResponse {
  nextCursor: string;
  events: PlatformEvent[];
}

export interface ResolveConversationResponse {
  conversationId: string;
  channelId: string;
  threadId?: string;
  rawId?: string;
}

export interface CreateMessageRequest {
  workspaceId?: string;
  conversationId: string;
  channelId?: string;
  threadId?: string;
  text?: string;
  content?: string;
  role?: string;
  author?: string;
  status?: 'streaming' | 'completed' | string;
  clientToken?: string;
  userId?: string;
  metadata?: Record<string, unknown>;
}

export interface CreateMessageResponse {
  messageId: string;
  revision?: number;
}

export interface PatchMessageRequest {
  text?: string;
  metadata?: Record<string, unknown>;
}

export interface PendingAckState {
  cursor: string;
  eventIds: string[];
}

export interface PluginPersistentState {
  cursor: string;
  processedEventIds: string[];
  clientTokenMessageMap: Record<string, string>;
  pendingAck: PendingAckState | null;
}

export interface PluginRuntimeConfig {
  baseUrl: string;
  token: string;
  pluginId: string;
  tokenUserId: string;
  pollIntervalMs: number;
  defaultCursor: string;
  stateFilePath: string;
  assistantName: string;
}
