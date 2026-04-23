import { beforeEach, describe, expect, it, vi } from 'vitest';

const { queryMock } = vi.hoisted(() => ({
  queryMock: vi.fn(),
}));

vi.mock('../db/index.js', () => ({
  default: {
    query: queryMock,
  },
}));

import {
  createPlatformNode,
  ensureDefaultPlatformNode,
  listPlatformNodes,
  nextDefaultNodeName,
  renamePlatformNode,
} from './platformNodeService.js';

describe('platformNodeService', () => {
  beforeEach(() => {
    queryMock.mockReset();
  });

  it('computes next default node name', () => {
    const result = nextDefaultNodeName([
      {
        nodeId: 'n1',
        displayName: 'openclaw 1',
        pluginId: 'p1',
        createdAt: '',
        updatedAt: '',
      },
      {
        nodeId: 'n2',
        displayName: 'openclaw 2',
        pluginId: 'p2',
        createdAt: '',
        updatedAt: '',
      },
    ]);
    expect(result).toBe('openclaw 3');
  });

  it('lists nodes in created order', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [{
        node_id: 'node_1',
        display_name: 'openclaw 1',
        plugin_id: 'plugin_node_1',
        created_at: '2026-04-21T00:00:00.000Z',
        updated_at: '2026-04-21T00:00:00.000Z',
      }],
    });

    const nodes = await listPlatformNodes('u-1');
    expect(nodes).toHaveLength(1);
    expect(nodes[0].displayName).toBe('openclaw 1');
  });

  it('creates node with provided display name', async () => {
    queryMock
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({
        rows: [{
          node_id: 'node_abc',
          display_name: 'my node',
          plugin_id: 'plugin_node_abc',
          created_at: '2026-04-21T00:00:00.000Z',
          updated_at: '2026-04-21T00:00:00.000Z',
        }],
      });

    const created = await createPlatformNode('u-1', { displayName: 'my node' });
    expect(created.displayName).toBe('my node');
    expect(queryMock).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO platform_nodes'),
      expect.arrayContaining(['u-1', expect.any(String), 'my node', expect.any(String)]),
    );
  });

  it('renames node and rejects empty names', async () => {
    await expect(renamePlatformNode('u-1', 'node_1', '   ')).rejects.toThrow(
      'DISPLAY_NAME_REQUIRED',
    );

    queryMock.mockResolvedValueOnce({
      rows: [{
        node_id: 'node_1',
        display_name: 'aws node',
        plugin_id: 'plugin_node_1',
        created_at: '2026-04-21T00:00:00.000Z',
        updated_at: '2026-04-21T00:01:00.000Z',
      }],
    });

    const updated = await renamePlatformNode('u-1', 'node_1', 'aws node');
    expect(updated?.displayName).toBe('aws node');
  });

  it('ensures default node when none exists', async () => {
    queryMock
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({
        rows: [{
          node_id: 'node_default',
          display_name: 'openclaw 1',
          plugin_id: 'plugin_local_main',
          created_at: '2026-04-21T00:00:00.000Z',
          updated_at: '2026-04-21T00:00:00.000Z',
        }],
      });

    const node = await ensureDefaultPlatformNode('u-1');
    expect(node.pluginId).toBe('plugin_local_main');
  });
});
