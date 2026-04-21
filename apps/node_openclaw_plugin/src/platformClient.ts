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
  readonly retryAfterMs?: number;

  constructor(
    status: number,
    message: string,
    code?: string,
    retryable?: boolean,
    retryAfterMs?: number,
  ) {
    super(message);
    this.name = 'PlatformHttpError';
    this.status = status;
    this.code = code;
    this.retryable = retryable;
    this.retryAfterMs = retryAfterMs;
  }
}

function parseRetryAfterMs(value: string | null): number | undefined {
  if (!value) {
    return undefined;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }

  const asSeconds = Number.parseInt(trimmed, 10);
  if (Number.isFinite(asSeconds) && asSeconds >= 0) {
    return asSeconds * 1000;
  }

  const asDate = Date.parse(trimmed);
  if (!Number.isNaN(asDate)) {
    return Math.max(0, asDate - Date.now());
  }

  return undefined;
}

export class PlatformClient {
  constructor(
    private readonly baseUrl: string,
    private readonly token: string,
    private readonly pluginId: string,
    private readonly resolveSignal?: () => AbortSignal | undefined,
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

  /**
   * Opens a persistent SSE connection to `/api/v1/platform/events/stream`
   * and yields a [GetEventsResponse] each time the server pushes new events.
   * The stream completes when the underlying HTTP connection closes;
   * callers are responsible for reconnecting as needed.
   */
  async *listenEvents(cursor: string): AsyncGenerator<GetEventsResponse, void, undefined> {
    const params = new URLSearchParams({ cursor });
    const url = new URL(`/api/v1/platform/events/stream?${params.toString()}`, this.baseUrl);

    const response = await fetch(url, {
      signal: this.resolveSignal?.(),
      headers: {
        Authorization: `Bearer ${this.token}`,
        'X-Bricks-Plugin-Id': this.pluginId,
        Accept: 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
    });

    if (!response.ok) {
      const statusSuffix = response.statusText ? ` ${response.statusText}` : '';
      throw new PlatformHttpError(
        response.status,
        `Failed to open platform events stream: ${response.status}${statusSuffix}`,
      );
    }

    if (!response.body) {
      throw new Error('Response body is null');
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let partial = '';
    let pendingData: string | null = null;

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        partial += decoder.decode(value, { stream: true });

        // Extract all complete lines (split on \n; trimRight removes any \r).
        const parts = partial.split('\n');
        partial = parts[parts.length - 1]; // last part may be incomplete

        for (let i = 0; i < parts.length - 1; i++) {
          const line = parts[i].trimEnd();

          if (line.length === 0) {
            // Empty line signals end of one SSE event – dispatch it.
            if (pendingData !== null) {
              try {
                const parsed = JSON.parse(pendingData) as GetEventsResponse;
                yield parsed;
              } catch {
                // ignore malformed SSE events
              }
              pendingData = null;
            }
          } else if (line.startsWith('data: ')) {
            pendingData = line.substring(6);
          } else if (line.startsWith('data:')) {
            pendingData = line.substring(5);
          }
          // Lines starting with ':' are SSE comments (e.g. heartbeats); ignore.
        }
      }
    } finally {
      reader.releaseLock();
    }
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const response = await fetch(new URL(path, this.baseUrl), {
      ...init,
      signal: init?.signal ?? this.resolveSignal?.(),
      headers: {
        Authorization: `Bearer ${this.token}`,
        'X-Bricks-Plugin-Id': this.pluginId,
        'Content-Type': 'application/json',
        ...init?.headers,
      },
    });

    if (!response.ok) {
      const statusSuffix = response.statusText ? ` ${response.statusText}` : '';
      const message = `Platform request failed: ${response.status}${statusSuffix}`;
      const retryAfterMs = parseRetryAfterMs(response.headers.get('Retry-After'));
      try {
        const body = (await response.json()) as {
          error?: { code?: string; message?: string; retryable?: boolean };
        };
        throw new PlatformHttpError(
          response.status,
          body.error?.message ?? message,
          body.error?.code,
          body.error?.retryable ?? (response.status === 429 || response.status >= 500),
          retryAfterMs,
        );
      } catch (error) {
        if (error instanceof PlatformHttpError) {
          throw error;
        }
        throw new PlatformHttpError(
          response.status,
          message,
          undefined,
          response.status === 429 || response.status >= 500,
          retryAfterMs,
        );
      }
    }

    if (response.status === 204) {
      return {} as T;
    }

    return (await response.json()) as T;
  }
}
