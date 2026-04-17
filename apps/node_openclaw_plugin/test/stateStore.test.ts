import { mkdtemp, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { afterEach, describe, expect, it } from 'vitest';
import { createDefaultState, FileStateStore } from '../src/stateStore.js';

const cleanupPaths: string[] = [];

afterEach(async () => {
  while (cleanupPaths.length > 0) {
    const path = cleanupPaths.pop();
    if (path) {
      await rm(path, { recursive: true, force: true });
    }
  }
});

describe('FileStateStore', () => {
  it('returns default state when file does not exist', async () => {
    const root = await mkdtemp(join(tmpdir(), 'node-openclaw-test-'));
    cleanupPaths.push(root);

    const store = new FileStateStore(join(root, 'state.json'), 'cur_0');
    const loaded = await store.load();
    expect(loaded).toEqual(createDefaultState('cur_0'));
  });

  it('persists cursor and processed event list', async () => {
    const root = await mkdtemp(join(tmpdir(), 'node-openclaw-test-'));
    cleanupPaths.push(root);

    const store = new FileStateStore(join(root, 'state.json'), 'cur_0', 3);
    await store.save({
      cursor: 'cur_12',
      processedEventIds: ['evt_1', 'evt_2', 'evt_3', 'evt_4'],
      clientTokenMessageMap: {
        'evt:evt_4': 'msg_4',
      },
      pendingAck: {
        cursor: 'cur_12',
        eventIds: ['evt_3', 'evt_4'],
      },
    });

    const loaded = await store.load();
    expect(loaded.cursor).toBe('cur_12');
    expect(loaded.processedEventIds).toEqual(['evt_2', 'evt_3', 'evt_4']);
    expect(loaded.clientTokenMessageMap['evt:evt_4']).toBe('msg_4');
    expect(loaded.pendingAck).toEqual({ cursor: 'cur_12', eventIds: ['evt_3', 'evt_4'] });
  });
});
