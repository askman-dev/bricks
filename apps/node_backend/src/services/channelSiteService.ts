import crypto from 'crypto';
import { exec, execFile } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import { promisify } from 'util';
import pool from '../db/index.js';
import {
  channelDirectory,
  ensureChannelBaseDirectories,
  ensureSafeChannelRelativePath,
  resolveChannelPath,
} from './channelFileService.js';
import { getMediaAssetForUser, resolveMediaAssetPath } from './mediaService.js';

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);

const DEFAULT_PUBLIC_SITE_DOMAIN = 'craft-spaces.bricks.cool';
const MAX_WORKSPACE_FILE_BYTES = 2 * 1024 * 1024;
const MAX_SHELL_OUTPUT_BYTES = 64 * 1024;

export interface ChannelSite {
  id: string;
  userId: string;
  channelId: string;
  publicSlug: string;
  latestBuildStatus: 'not_built' | 'succeeded' | 'failed';
  latestBuildAt: string | null;
  createdAt: string;
  updatedAt: string;
}

interface ChannelSiteRow {
  id: string;
  user_id: string;
  channel_id: string;
  public_slug: string;
  latest_build_status: 'not_built' | 'succeeded' | 'failed';
  latest_build_at: string | null;
  created_at: string;
  updated_at: string;
}

export class ChannelSiteError extends Error {
  constructor(message: string, public readonly statusCode = 400) {
    super(message);
    this.name = 'ChannelSiteError';
  }
}

function toChannelSite(row: ChannelSiteRow): ChannelSite {
  return {
    id: row.id,
    userId: row.user_id,
    channelId: row.channel_id,
    publicSlug: row.public_slug,
    latestBuildStatus: row.latest_build_status,
    latestBuildAt: row.latest_build_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function publicSiteDomain(): string {
  return (process.env.BRICKS_PUBLIC_SITE_DOMAIN || DEFAULT_PUBLIC_SITE_DOMAIN).trim();
}

export function publicSiteUrl(publicSlug: string): string {
  const baseUrl = process.env.BRICKS_PUBLIC_SITE_BASE_URL?.trim();
  if (baseUrl) {
    return `${baseUrl.replace(/\/+$/, '')}/sites/${publicSlug}`;
  }
  return `https://${publicSlug}.${publicSiteDomain()}`;
}

function randomPublicSlug(): string {
  return `s-${crypto.randomBytes(6).toString('hex')}`;
}

export function workspaceRelativePath(relativePath: string): string {
  const safe = ensureSafeChannelRelativePath(relativePath);
  if (safe === 'workspace') {
    throw new ChannelSiteError('Workspace path must refer to a file or directory inside workspace');
  }
  if (!safe.startsWith('workspace/')) {
    return `workspace/${safe}`;
  }
  return safe;
}

export function workspacePath(userId: string, channelId: string, relativePath = '.'): string {
  if (relativePath === '.' || relativePath.trim() === '') {
    return path.join(channelDirectory(userId, channelId), 'workspace');
  }
  return resolveChannelPath(userId, channelId, workspaceRelativePath(relativePath));
}

export function jobsPath(userId: string, channelId: string, relativePath: string): string {
  return resolveChannelPath(userId, channelId, `jobs/${ensureSafeChannelRelativePath(relativePath)}`);
}

export function webDistPath(userId: string, channelId: string): string {
  return resolveChannelPath(userId, channelId, 'web/dist');
}

async function insertChannelSite(userId: string, channelId: string): Promise<ChannelSite> {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const publicSlug = randomPublicSlug();
    try {
      const result = await pool.query<ChannelSiteRow>(
        `INSERT INTO channel_sites (user_id, channel_id, public_slug)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [userId, channelId, publicSlug],
      );
      return toChannelSite(result.rows[0]);
    } catch (error) {
      if (error instanceof Error && /public_slug|unique/i.test(error.message)) {
        continue;
      }
      throw error;
    }
  }
  throw new ChannelSiteError('Could not allocate a unique public site slug', 500);
}

export async function ensureChannelSite(userId: string, channelId: string): Promise<ChannelSite> {
  const existing = await pool.query<ChannelSiteRow>(
    `SELECT * FROM channel_sites WHERE user_id = $1 AND channel_id = $2 LIMIT 1`,
    [userId, channelId],
  );
  if (existing.rows[0]) return toChannelSite(existing.rows[0]);

  try {
    return await insertChannelSite(userId, channelId);
  } catch (error) {
    if (error instanceof Error && /user_id|channel_id|unique/i.test(error.message)) {
      const retry = await pool.query<ChannelSiteRow>(
        `SELECT * FROM channel_sites WHERE user_id = $1 AND channel_id = $2 LIMIT 1`,
        [userId, channelId],
      );
      if (retry.rows[0]) return toChannelSite(retry.rows[0]);
    }
    throw error;
  }
}

export async function getChannelSiteForUser(userId: string, channelId: string): Promise<ChannelSite | null> {
  const result = await pool.query<ChannelSiteRow>(
    `SELECT * FROM channel_sites WHERE user_id = $1 AND channel_id = $2 LIMIT 1`,
    [userId, channelId],
  );
  return result.rows[0] ? toChannelSite(result.rows[0]) : null;
}

export async function getChannelSiteBySlug(publicSlug: string): Promise<ChannelSite | null> {
  const result = await pool.query<ChannelSiteRow>(
    `SELECT * FROM channel_sites WHERE public_slug = $1 LIMIT 1`,
    [publicSlug],
  );
  return result.rows[0] ? toChannelSite(result.rows[0]) : null;
}

function starterFiles() {
  return new Map<string, string>([
    [
      'package.json',
      JSON.stringify(
        {
          scripts: {
            dev: 'vite',
            build: 'vite build --outDir ../web/dist-next --emptyOutDir',
            preview: 'vite preview',
          },
          dependencies: {
            '@vitejs/plugin-react': '^5.0.0',
            vite: '^7.0.0',
            typescript: '^5.5.0',
            react: '^19.0.0',
            'react-dom': '^19.0.0',
          },
          devDependencies: {},
        },
        null,
        2,
      ) + '\n',
    ],
    [
      'package-lock.json',
      JSON.stringify(
        {
          lockfileVersion: 3,
          requires: true,
          packages: {
            '': {
              dependencies: {
                '@vitejs/plugin-react': '^5.0.0',
                vite: '^7.0.0',
                typescript: '^5.5.0',
                react: '^19.0.0',
                'react-dom': '^19.0.0',
              },
            },
          },
        },
        null,
        2,
      ) + '\n',
    ],
    ['index.html', '<!doctype html>\n<div id="root"></div><script type="module" src="/src/main.tsx"></script>\n'],
    [
      'tsconfig.json',
      JSON.stringify(
        {
          compilerOptions: {
            target: 'ES2020',
            useDefineForClassFields: true,
            lib: ['DOM', 'DOM.Iterable', 'ES2020'],
            allowJs: false,
            skipLibCheck: true,
            esModuleInterop: true,
            allowSyntheticDefaultImports: true,
            strict: true,
            forceConsistentCasingInFileNames: true,
            module: 'ESNext',
            moduleResolution: 'Node',
            resolveJsonModule: true,
            isolatedModules: true,
            noEmit: true,
            jsx: 'react-jsx',
          },
          include: ['src'],
          references: [],
        },
        null,
        2,
      ) + '\n',
    ],
    ['src/main.tsx', "import React from 'react';\nimport { createRoot } from 'react-dom/client';\nimport './styles.css';\n\ncreateRoot(document.getElementById('root')!).render(\n  <React.StrictMode>\n    <main className=\"site-shell\">\n      <h1>Bricks Site</h1>\n      <p>Ask Bricks to shape this channel website.</p>\n    </main>\n  </React.StrictMode>,\n);\n"],
    ['src/styles.css', ':root { font-family: Inter, ui-sans-serif, system-ui, sans-serif; color: #111827; background: #f8fafc; }\nbody { margin: 0; }\n.site-shell { min-height: 100vh; display: grid; place-content: center; gap: 12px; padding: 32px; text-align: center; }\nh1 { margin: 0; font-size: clamp(40px, 8vw, 88px); }\np { margin: 0; color: #475569; font-size: 18px; }\n'],
    ['public/robots.txt', 'User-agent: *\nDisallow: /\n'],
    ['.gitignore', 'node_modules/\ndist/\n../web/dist-next/\n.env\n.DS_Store\n'],
  ]);
}

function isMissingExecutableError(error: unknown, executable: string): boolean {
  if (!(error instanceof Error)) return false;
  const maybeCode = (error as NodeJS.ErrnoException).code;
  return maybeCode === 'ENOENT' && error.message.includes(executable);
}

async function initializeGitRepositoryIfAvailable(root: string): Promise<void> {
  try {
    await fs.access(path.join(root, '.git'));
    return;
  } catch {
    // Continue to initialization below.
  }

  try {
    await execFileAsync('git', ['init'], { cwd: root });
    await execFileAsync('git', ['add', '.'], { cwd: root });
    await execFileAsync('git', ['commit', '-m', 'Initial Bricks site'], {
      cwd: root,
      env: {
        ...process.env,
        GIT_AUTHOR_NAME: 'Bricks',
        GIT_AUTHOR_EMAIL: 'bricks@localhost',
        GIT_COMMITTER_NAME: 'Bricks',
        GIT_COMMITTER_EMAIL: 'bricks@localhost',
      },
    });
  } catch (error) {
    if (!isMissingExecutableError(error, 'git')) {
      throw error;
    }
    const markerPath = path.join(root, '..', '.bricks', 'git-unavailable.json');
    await fs.mkdir(path.dirname(markerPath), { recursive: true });
    await fs.writeFile(
      markerPath,
      JSON.stringify(
        {
          ok: false,
          reason: 'git executable is not available in this runtime',
          createdAt: new Date().toISOString(),
        },
        null,
        2,
      ) + '\n',
      'utf8',
    );
  }
}

export async function ensureWebsiteWorkspace(userId: string, channelId: string): Promise<ChannelSite> {
  const site = await ensureChannelSite(userId, channelId);
  await ensureChannelBaseDirectories(userId, channelId);
  const root = workspacePath(userId, channelId);
  const packageJson = path.join(root, 'package.json');
  let exists = true;
  try {
    await fs.access(packageJson);
  } catch {
    exists = false;
  }

  if (!exists) {
    for (const [relativePath, content] of starterFiles()) {
      const absolutePath = path.join(root, relativePath);
      await fs.mkdir(path.dirname(absolutePath), { recursive: true });
      await fs.writeFile(absolutePath, content, 'utf8');
    }
  }

  await initializeGitRepositoryIfAvailable(root);

  return site;
}

export function channelSiteDto(site: ChannelSite) {
  return {
    id: site.id,
    channelId: site.channelId,
    publicSlug: site.publicSlug,
    publicUrl: publicSiteUrl(site.publicSlug),
    latestBuildStatus: site.latestBuildStatus,
    latestBuildAt: site.latestBuildAt,
    paths: {
      workspace: 'workspace/',
      dist: 'web/dist/',
      latestBuildLog: 'jobs/build.log',
      latestBuildStatus: 'jobs/build.json',
      futureGitRemote: null,
    },
  };
}

export async function listWorkspaceFiles(params: {
  userId: string;
  channelId: string;
  relativePath?: string;
}): Promise<Array<{ path: string; type: 'file' | 'directory'; sizeBytes: number }>> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const baseRelative = params.relativePath ? workspaceRelativePath(params.relativePath) : 'workspace';
  const absolutePath = baseRelative === 'workspace'
    ? workspacePath(params.userId, params.channelId)
    : resolveChannelPath(params.userId, params.channelId, baseRelative);
  const entries = await fs.readdir(absolutePath, { withFileTypes: true });
  const results = [];
  for (const entry of entries) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const child = path.join(absolutePath, entry.name);
    const stat = await fs.stat(child);
    const relative = path.relative(workspacePath(params.userId, params.channelId), child).replace(/\\/g, '/');
    results.push({
      path: relative,
      type: entry.isDirectory() ? 'directory' as const : 'file' as const,
      sizeBytes: stat.size,
    });
  }
  return results.sort((a, b) => a.path.localeCompare(b.path));
}

export async function readWorkspaceFile(params: {
  userId: string;
  channelId: string;
  relativePath: string;
}): Promise<{ path: string; content: string; sizeBytes: number }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const absolutePath = workspacePath(params.userId, params.channelId, params.relativePath);
  const stat = await fs.stat(absolutePath);
  if (!stat.isFile()) {
    throw new ChannelSiteError('Workspace path is not a file');
  }
  if (stat.size > MAX_WORKSPACE_FILE_BYTES) {
    throw new ChannelSiteError('Workspace file is too large to read');
  }
  return {
    path: ensureSafeChannelRelativePath(params.relativePath),
    content: await fs.readFile(absolutePath, 'utf8'),
    sizeBytes: stat.size,
  };
}

export async function writeWorkspaceFile(params: {
  userId: string;
  channelId: string;
  relativePath: string;
  content: string;
}): Promise<{ path: string; sizeBytes: number }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  if (Buffer.byteLength(params.content, 'utf8') > MAX_WORKSPACE_FILE_BYTES) {
    throw new ChannelSiteError('Workspace file is too large to write');
  }
  const safe = ensureSafeChannelRelativePath(params.relativePath);
  const absolutePath = workspacePath(params.userId, params.channelId, safe);
  await fs.mkdir(path.dirname(absolutePath), { recursive: true });
  await fs.writeFile(absolutePath, params.content, 'utf8');
  return { path: safe, sizeBytes: Buffer.byteLength(params.content, 'utf8') };
}

export async function makeWorkspaceDirectory(params: {
  userId: string;
  channelId: string;
  relativePath: string;
}): Promise<{ path: string }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const safe = ensureSafeChannelRelativePath(params.relativePath);
  await fs.mkdir(workspacePath(params.userId, params.channelId, safe), { recursive: true });
  return { path: safe };
}

export async function deleteWorkspacePath(params: {
  userId: string;
  channelId: string;
  relativePath: string;
}): Promise<{ path: string; deleted: boolean }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const safe = ensureSafeChannelRelativePath(params.relativePath);
  if (safe === '.git' || safe.startsWith('.git/') || safe === 'node_modules' || safe.startsWith('node_modules/')) {
    throw new ChannelSiteError('Cannot delete protected workspace paths');
  }
  await fs.rm(workspacePath(params.userId, params.channelId, safe), { recursive: true, force: true });
  return { path: safe, deleted: true };
}

function truncateOutput(value: string): string {
  const buffer = Buffer.from(value);
  if (buffer.length <= MAX_SHELL_OUTPUT_BYTES) return value;
  return `${buffer.subarray(0, MAX_SHELL_OUTPUT_BYTES).toString('utf8')}\n[output truncated]`;
}

export async function runWorkspaceCommand(params: {
  userId: string;
  channelId: string;
  command: string;
}): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const command = params.command.trim();
  if (!command) {
    throw new ChannelSiteError('command is required');
  }
  try {
    const result = await execAsync(command, {
      cwd: workspacePath(params.userId, params.channelId),
      timeout: 120_000,
      maxBuffer: MAX_SHELL_OUTPUT_BYTES * 4,
    });
    return { stdout: truncateOutput(result.stdout), stderr: truncateOutput(result.stderr), exitCode: 0 };
  } catch (error) {
    const err = error as Error & { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: truncateOutput(err.stdout ?? ''),
      stderr: truncateOutput(err.stderr ?? err.message),
      exitCode: typeof err.code === 'number' ? err.code : 1,
    };
  }
}

async function updateBuildStatus(
  userId: string,
  channelId: string,
  status: 'succeeded' | 'failed',
): Promise<ChannelSite> {
  const result = await pool.query<ChannelSiteRow>(
    `UPDATE channel_sites
        SET latest_build_status = $3,
            latest_build_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1 AND channel_id = $2
      RETURNING *`,
    [userId, channelId, status],
  );
  return toChannelSite(result.rows[0]);
}

export async function buildChannelSite(params: {
  userId: string;
  channelId: string;
}): Promise<{ site: ChannelSite; ok: boolean; log: string }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const logPath = jobsPath(params.userId, params.channelId, 'build.log');
  const statusPath = jobsPath(params.userId, params.channelId, 'build.json');
  const distNext = resolveChannelPath(params.userId, params.channelId, 'web/dist-next');
  const dist = webDistPath(params.userId, params.channelId);
  await fs.rm(distNext, { recursive: true, force: true });

  let log = '';
  let ok = false;
  try {
    const install = await runWorkspaceCommand({
      userId: params.userId,
      channelId: params.channelId,
      command: 'npm install',
    });
    log += `$ npm install\n${install.stdout}${install.stderr}\n`;
    if (install.exitCode !== 0) {
      throw new ChannelSiteError('npm install failed');
    }
    const build = await runWorkspaceCommand({
      userId: params.userId,
      channelId: params.channelId,
      command: 'npm run build',
    });
    log += `$ npm run build\n${build.stdout}${build.stderr}\n`;
    if (build.exitCode !== 0) {
      throw new ChannelSiteError('npm run build failed');
    }
    await fs.rm(dist, { recursive: true, force: true });
    await fs.rename(distNext, dist);
    ok = true;
  } catch (error) {
    log += `\nBuild failed: ${error instanceof Error ? error.message : String(error)}\n`;
  } finally {
    await fs.mkdir(path.dirname(logPath), { recursive: true });
    await fs.writeFile(logPath, truncateOutput(log), 'utf8');
  }

  const site = await updateBuildStatus(params.userId, params.channelId, ok ? 'succeeded' : 'failed');
  await fs.writeFile(
    statusPath,
    JSON.stringify(
      {
        ok,
        status: site.latestBuildStatus,
        publicUrl: publicSiteUrl(site.publicSlug),
        updatedAt: site.latestBuildAt,
      },
      null,
      2,
    ) + '\n',
    'utf8',
  );
  return { site, ok, log: truncateOutput(log) };
}

export async function copyMediaToSiteAssets(params: {
  userId: string;
  channelId: string;
  mediaId: string;
  filename?: string | null;
}): Promise<{ mediaId: string; path: string; publicPath: string }> {
  await ensureWebsiteWorkspace(params.userId, params.channelId);
  const media = await getMediaAssetForUser(params.userId, params.mediaId);
  if (!media || media.channelId !== params.channelId) {
    throw new ChannelSiteError('Media asset not found in the current channel', 404);
  }
  const source = await resolveMediaAssetPath(media);
  const basename = path.basename(params.filename?.trim() || media.filename || source).replace(/[^A-Za-z0-9._-]+/g, '-');
  const safeName = basename && basename !== '.' && basename !== '..' ? basename : `${media.id}`;
  const relative = `public/assets/${media.id}-${safeName}`;
  const target = workspacePath(params.userId, params.channelId, relative);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.copyFile(source, target);
  return {
    mediaId: media.id,
    path: relative,
    publicPath: `/assets/${media.id}-${safeName}`,
  };
}
