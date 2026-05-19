import { beforeEach, describe, expect, it, vi } from 'vitest';

const { poolMock } = vi.hoisted(() => ({
  poolMock: {
    dialect: 'turso' as 'postgres' | 'turso',
    query: vi.fn(),
  },
}));

vi.mock('../db/index.js', () => ({
  default: poolMock,
}));

describe('assetTableService SQL compatibility', () => {
  beforeEach(() => {
    vi.resetModules();
    poolMock.dialect = 'turso';
    poolMock.query.mockReset();
  });

  it('uses Turso-compatible timestamp SQL when creating a table', async () => {
    poolMock.query.mockResolvedValueOnce({
      rows: [
        {
          id: 'tbl-1',
          user_id: 'u-1',
          resource_id: 'sports-day-prep',
          title: 'Sports Day Preparation',
          created_at: '2026-05-17 00:00:00',
          updated_at: '2026-05-17 00:00:00',
        },
      ],
      rowCount: 1,
    });

    const { createTable } = await import('./assetTableService.js');
    const table = await createTable('u-1', {
      resourceId: 'sports-day-prep',
      title: 'Sports Day Preparation',
    });

    const sql = poolMock.query.mock.calls[0][0] as string;
    expect(sql).toContain('updated_at = CURRENT_TIMESTAMP');
    expect(sql).not.toContain('NOW()');
    expect(table).toMatchObject({
      userId: 'u-1',
      resourceId: 'sports-day-prep',
      title: 'Sports Day Preparation',
    });
  });

  it('uses Turso-compatible JSON SQL for row writes and parses JSON text rows', async () => {
    poolMock.query.mockResolvedValueOnce({
      rows: [
        {
          id: 'row-1',
          user_id: 'u-1',
          resource_id: 'sports-day-prep',
          display_number: 1,
          cell_data: '{"task":"Buy snacks","count":3}',
          is_deleted: 0,
          created_at: '2026-05-17 00:00:00',
          updated_at: '2026-05-17 00:00:00',
        },
      ],
      rowCount: 1,
    });

    const { addRow } = await import('./assetTableService.js');
    const row = await addRow('u-1', 'sports-day-prep', { task: 'Buy snacks' });

    const sql = poolMock.query.mock.calls[0][0] as string;
    expect(sql).toContain('$3');
    expect(sql).not.toContain('::jsonb');
    expect(row.cellData).toEqual({ task: 'Buy snacks', count: null });
    expect(row.isDeleted).toBe(false);
  });

  it('uses Turso-compatible JSON merge SQL when updating a row', async () => {
    poolMock.query.mockResolvedValueOnce({
      rows: [
        {
          id: 'row-1',
          user_id: 'u-1',
          resource_id: 'sports-day-prep',
          display_number: 1,
          cell_data: '{"task":"Buy snacks","owner":"Alice"}',
          is_deleted: 0,
          created_at: '2026-05-17 00:00:00',
          updated_at: '2026-05-17 00:01:00',
        },
      ],
      rowCount: 1,
    });

    const { updateRow } = await import('./assetTableService.js');
    const row = await updateRow('u-1', 'sports-day-prep', 'row-1', {
      owner: 'Alice',
    });

    const sql = poolMock.query.mock.calls[0][0] as string;
    expect(sql).toContain("json_patch(COALESCE(cell_data, '{}'), $4)");
    expect(sql).toContain('updated_at = CURRENT_TIMESTAMP');
    expect(sql).not.toContain('NOW()');
    expect(sql).not.toContain('::jsonb');
    expect(row?.cellData).toEqual({ task: 'Buy snacks', owner: 'Alice' });
  });
});
