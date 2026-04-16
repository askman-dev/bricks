import type {
  CreateMessageRequest,
  CreateMessageResponse,
  GetEventsResponse,
  PatchMessageRequest,
  ResolveConversationResponse,
} from './types.js';

export class PlatformHttpError extends Error {
  readonly status: number;
  readonly code?: string;
  readonly retryable?: boolean;

  constructor(status: number, message: string, code?: string, retryable?: boolean) {
    super(message);
    this.name = 'PlatformHttpError';
    this.status = status;
    this.code = code;
    this.retryable = retryable;
  }
}

export class PlatformClient {
  constructor(
    private readonly baseUrl: string,
    private readonly token: string,
    private readonly pluginId: string,
  ) {}

  async getEvents(cursor: string, limit = 50): Promise<GetEventsResponse> {
    const params = new URLSearchParams({ cursor, limit: String(limit) });
    return this.request<GetEventsResponse>(`/api/v1/platform/events?${params.toString()}`);
  }

  async ackEvents(cursor: string, ackedEventIds: string[]): Promise<{ ok: boolean }> {
    return this.request<{ ok: boolean }>('/api/v1/platform/events/ack', {
      method: 'POST',
      body: JSON.stringify({ cursor, ackedEventIds }),
    });
  }

  async resolveConversation(args: {
    conversationId?: string;
    rawId?: string;
  }): Promise<ResolveConversationResponse> {
    const params = new URLSearchParams();
    if (args.conversationId) params.set('conversationId', args.conversationId);
    if (args.rawId) params.set('rawId', args.rawId);
    return this.request<ResolveConversationResponse>(`/api/v1/platform/conversations/resolve?${params.toString()}`);
  }

  async createMessage(payload: CreateMessageRequest): Promise<CreateMessageResponse> {
    return this.request<CreateMessageResponse>('/api/v1/platform/messages', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  async patchMessage(messageId: string, payload: PatchMessageRequest): Promise<{ ok: boolean }> {
    return this.request<{ ok: boolean }>(`/api/v1/platform/messages/${encodeURIComponent(messageId)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const response = await fetch(new URL(path, this.baseUrl), {
      ...init,
      headers: {
        Authorization: `Bearer ${this.token}`,
        'X-Bricks-Plugin-Id': this.pluginId,
        'Content-Type': 'application/json',
        ...init?.headers,
      },
    });

    if (!response.ok) {
      const message = `Platform request failed: ${response.status} ${response.statusText}`;
      try {
        const body = (await response.json()) as {
          error?: { code?: string; message?: string; retryable?: boolean };
        };
        throw new PlatformHttpError(
          response.status,
          body.error?.message ?? message,
          body.error?.code,
          body.error?.retryable,
        );
      } catch (error) {
        if (error instanceof PlatformHttpError) {
          throw error;
        }
        throw new PlatformHttpError(response.status, message);
      }
    }

    if (response.status === 204) {
      return {} as T;
    }

    return (await response.json()) as T;
  }
}
