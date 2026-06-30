import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

describe('channelFileService', () => {
  let tempDir: string;
  let previousRoot: string | undefined;

  beforeEach(async () => {
    previousRoot = process.env.BRICKS_CHANNEL_ROOT;
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'bricks-channel-root-'));
    process.env.BRICKS_CHANNEL_ROOT = tempDir;
  });

  afterEach(async () => {
    if (previousRoot === undefined) {
      delete process.env.BRICKS_CHANNEL_ROOT;
    } else {
      process.env.BRICKS_CHANNEL_ROOT = previousRoot;
    }
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('writes files inside a channel-scoped directory', async () => {
    const { channelDirectory, writeChannelFile } = await import('./channelFileService.js');
    const relativePath = await writeChannelFile({
      userId: 'user-1',
      channelId: 'feature/site',
      relativePath: 'media/uploads/a.png',
      data: Buffer.from('png-bytes'),
    });

    expect(relativePath).toBe('media/uploads/a.png');
    const written = await fs.readFile(
      path.join(channelDirectory('user-1', 'feature/site'), relativePath),
      'utf8',
    );
    expect(written).toBe('png-bytes');
    expect(channelDirectory('user-1', 'feature/site')).not.toContain('feature');
    expect(channelDirectory('user-1', 'feature/site')).not.toContain('user-1');
  });

  it('rejects absolute and parent-relative paths', async () => {
    const { resolveChannelPath } = await import('./channelFileService.js');

    expect(() => resolveChannelPath('user-1', 'default', '/tmp/file.png')).toThrow(
      /Invalid channel-relative path/,
    );
    expect(() => resolveChannelPath('user-1', 'default', '../file.png')).toThrow(
      /Invalid channel-relative path/,
    );
    expect(() => resolveChannelPath('user-1', 'default', 'media/../file.png')).toThrow(
      /Invalid channel-relative path/,
    );
    expect(() => resolveChannelPath('user-1', 'default', './file.png')).toThrow(
      /Invalid channel-relative path/,
    );
  });
});
