import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import type { PluginPersistentState } from './types.js';

export const DEFAULT_MAX_PROCESSED_EVENTS = 5000;

export function createDefaultState(defaultCursor: string): PluginPersistentState {
  return {
    cursor: defaultCursor,
    processedEventIds: [],
    clientTokenMessageMap: {},
    pendingAck: null,
  };
}

export class FileStateStore {
  constructor(
    private readonly filePath: string,
    private readonly defaultCursor: string,
    private readonly maxProcessedEvents = DEFAULT_MAX_PROCESSED_EVENTS,
  ) {}

  async load(): Promise<PluginPersistentState> {
    try {
      const raw = await readFile(this.filePath, 'utf8');
      const parsed = JSON.parse(raw) as PluginPersistentState;
      return {
        cursor: parsed.cursor || this.defaultCursor,
        processedEventIds: Array.isArray(parsed.processedEventIds) ? parsed.processedEventIds : [],
        clientTokenMessageMap: parsed.clientTokenMessageMap ?? {},
        pendingAck:
          parsed.pendingAck &&
          typeof parsed.pendingAck === 'object' &&
          typeof parsed.pendingAck.cursor === 'string' &&
          Array.isArray(parsed.pendingAck.eventIds)
            ? {
                cursor: parsed.pendingAck.cursor,
                eventIds: parsed.pendingAck.eventIds.filter(
                  (value): value is string => typeof value === 'string' && value.trim().length > 0,
                ),
              }
            : null,
      };
    } catch {
      return createDefaultState(this.defaultCursor);
    }
  }

  async save(state: PluginPersistentState): Promise<void> {
    await mkdir(dirname(this.filePath), { recursive: true });
    const normalized: PluginPersistentState = {
      ...state,
      processedEventIds: state.processedEventIds.slice(-this.maxProcessedEvents),
    };
    await writeFile(this.filePath, JSON.stringify(normalized, null, 2), 'utf8');
  }
}
