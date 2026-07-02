import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

describe('channelFileService', () => {
  let tempDir: string;
  let previousRoot: string | undefined;

  beforeEach(async () => {
    previousRoot = process.env.BRICKS_SANDBOX_ROOT;
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'bricks-sandbox-root-'));
    process.env.BRICKS_SANDBOX_ROOT = tempDir;
  });

  afterEach(async () => {
    if (previousRoot === undefined) {
      delete process.env.BRICKS_SANDBOX_ROOT;
    } else {
      process.env.BRICKS_SANDBOX_ROOT = previousRoot;
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

  it('places multiple channels for one user under the same sandbox root', async () => {
    const { channelDirectory, userDirectory } = await import('./channelFileService.js');

    const userRoot = userDirectory('user-1');
    const firstChannel = channelDirectory('user-1', 'channel-a');
    const secondChannel = channelDirectory('user-1', 'channel-b');
    const otherUserChannel = channelDirectory('user-2', 'channel-a');

    expect(firstChannel.startsWith(`${userRoot}${path.sep}`)).toBe(true);
    expect(secondChannel.startsWith(`${userRoot}${path.sep}`)).toBe(true);
    expect(otherUserChannel.startsWith(`${userRoot}${path.sep}`)).toBe(false);
    expect(firstChannel).not.toBe(secondChannel);
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
