import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

// Hoist mocks so vi.mock factory closures can reference them.
const execFileAsyncMock = vi.hoisted(() => vi.fn());
const execFileMock = vi.hoisted(() => vi.fn());

vi.mock('node:child_process', () => ({ execFile: execFileMock }));

// Override promisify so that promisify(execFile) → execFileAsyncMock.
// This avoids the util.promisify.custom symbol issue with plain vi.fn() stubs.
vi.mock('node:util', async (importOriginal) => {
  const original = await importOriginal<typeof import('node:util')>();
  return {
    ...original,
    promisify: (fn: Function) =>
      fn === execFileMock ? execFileAsyncMock : original.promisify(fn),
  };
});

import {
  listOpenClawRuntimeAgents,
  normalizeOpenClawRuntimeAgents,
} from './openclawAgentRuntimeService.js';

describe('normalizeOpenClawRuntimeAgents', () => {
  it('returns empty array for empty input', () => {
    expect(normalizeOpenClawRuntimeAgents('node_1', [])).toEqual([]);
  });

  it('normalizes a valid agent list', () => {
    const raw = [{ id: 'agent1', displayName: 'Agent One', description: 'desc' }];
    const result = normalizeOpenClawRuntimeAgents('node_1', raw);
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      nodeId: 'node_1',
      sourcePlatform: 'openclaw',
      agentId: 'agent1',
      displayName: 'Agent One',
      description: 'desc',
    });
  });

  it('deduplicates agents with the same id', () => {
    const raw = [
      { id: 'dup', displayName: 'First' },
      { id: 'dup', displayName: 'Second' },
    ];
    const result = normalizeOpenClawRuntimeAgents('node_1', raw);
    expect(result).toHaveLength(1);
    expect(result[0].displayName).toBe('First');
  });

  it('skips items without a resolvable id', () => {
    const result = normalizeOpenClawRuntimeAgents('node_1', [{ foo: 'bar' }]);
    expect(result).toEqual([]);
  });
});

describe('listOpenClawRuntimeAgents', () => {
  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    vi.spyOn(console, 'debug').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns empty array when openclaw binary is not found (ENOENT)', async () => {
    const err = Object.assign(new Error('not found'), { code: 'ENOENT' });
    execFileAsyncMock.mockRejectedValue(err);

    const result = await listOpenClawRuntimeAgents('node_1');
    expect(result).toEqual([]);
    expect(console.debug).toHaveBeenCalledWith(
      expect.stringContaining('openclaw binary not found'),
    );
  });

  it('returns empty array when openclaw exits with non-zero code', async () => {
    const err = Object.assign(new Error('Command failed'), { code: 1, stderr: 'some error' });
    execFileAsyncMock.mockRejectedValue(err);

    const result = await listOpenClawRuntimeAgents('node_1');
    expect(result).toEqual([]);
    expect(console.error).toHaveBeenCalledWith(
      expect.stringContaining('openclaw agents list failed'),
      expect.anything(),
    );
  });

  it('returns empty array when openclaw output is invalid JSON', async () => {
    execFileAsyncMock.mockResolvedValue({ stdout: 'not-valid-json', stderr: '' });

    const result = await listOpenClawRuntimeAgents('node_1');
    expect(result).toEqual([]);
    expect(console.error).toHaveBeenCalledWith(
      expect.stringContaining('invalid JSON'),
      expect.any(String),
    );
  });

  it('returns empty array when stdout is empty', async () => {
    execFileAsyncMock.mockResolvedValue({ stdout: '', stderr: '' });

    const result = await listOpenClawRuntimeAgents('node_1');
    expect(result).toEqual([]);
  });

  it('returns normalized agents on success', async () => {
    const payload = JSON.stringify([
      { id: 'agent1', displayName: 'Agent One', description: 'hello' },
    ]);
    execFileAsyncMock.mockResolvedValue({ stdout: payload, stderr: '' });

    const result = await listOpenClawRuntimeAgents('node_1');
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      nodeId: 'node_1',
      agentId: 'agent1',
      displayName: 'Agent One',
    });
  });
});
