import fs from 'fs/promises';
import path from 'path';
import {
  getSandboxRoot,
  opaqueSandboxSegment,
  userSandboxChannelDirectory,
  userSandboxFsRoot,
} from './userSandboxService.js';

export function getChannelRoot(): string {
  return path.join(getSandboxRoot(), 'channels-legacy-view');
}

export function userDirectory(userId: string): string {
  return userSandboxFsRoot(userId);
}

export function channelDirectory(userId: string, channelId: string): string {
  return userSandboxChannelDirectory(userId, channelId);
}

export function channelOpaqueSegment(channelId: string): string {
  return opaqueSandboxSegment('channel', channelId);
}

export function ensureSafeChannelRelativePath(relativePath: string): string {
  const normalized = relativePath.replace(/\\/g, '/');
  if (!normalized || normalized.startsWith('/') || normalized.includes('\0')) {
    throw new Error('Invalid channel-relative path');
  }
  const parts = normalized.split('/');
  if (parts.some((part) => part === '..' || part === '.' || part === '')) {
    throw new Error('Invalid channel-relative path');
  }
  return normalized;
}

export function resolveChannelPath(userId: string, channelId: string, relativePath: string): string {
  const channelDir = channelDirectory(userId, channelId);
  const safeRelativePath = ensureSafeChannelRelativePath(relativePath);
  const resolved = path.resolve(channelDir, safeRelativePath);
  const channelRootWithSep = `${path.resolve(channelDir)}${path.sep}`;
  if (resolved !== channelDir && !resolved.startsWith(channelRootWithSep)) {
    throw new Error('Resolved path escapes channel root');
  }
  return resolved;
}

export async function ensureChannelBaseDirectories(userId: string, channelId: string): Promise<void> {
  const channelDir = channelDirectory(userId, channelId);
  await fs.mkdir(path.join(channelDir, 'workspace'), { recursive: true });
  await fs.mkdir(path.join(channelDir, 'media', 'uploads'), { recursive: true });
  await fs.mkdir(path.join(channelDir, 'media', 'generated', 'images'), { recursive: true });
  await fs.mkdir(path.join(channelDir, 'media', 'generated', 'videos'), { recursive: true });
  await fs.mkdir(path.join(channelDir, 'media', 'thumbnails'), { recursive: true });
  await fs.mkdir(path.join(channelDir, 'web', 'dist'), { recursive: true });
  await fs.mkdir(path.join(channelDir, 'jobs'), { recursive: true });
  await fs.mkdir(path.join(channelDir, '.bricks'), { recursive: true });
}

export async function writeChannelFile(params: {
  userId: string;
  channelId: string;
  relativePath: string;
  data: Buffer;
}): Promise<string> {
  await ensureChannelBaseDirectories(params.userId, params.channelId);
  const safeRelativePath = ensureSafeChannelRelativePath(params.relativePath);
  const absolutePath = resolveChannelPath(params.userId, params.channelId, safeRelativePath);
  await fs.mkdir(path.dirname(absolutePath), { recursive: true });
  await fs.writeFile(absolutePath, params.data, { flag: 'wx' });
  return safeRelativePath;
}
