import express, { NextFunction, Request, Response } from 'express';
import fs from 'fs/promises';
import path from 'path';
import { getChannelSiteBySlug, publicSiteDomain, webDistPath } from '../services/channelSiteService.js';

const router = express.Router();

const LONG_STATIC_CACHE = 'public, max-age=31536000, immutable';
const HTML_CACHE = 'no-store, no-cache, must-revalidate, max-age=0';
const GENERATED_SITE_CSP = [
  "default-src 'self' https: data: blob:",
  "script-src 'self' https: 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob:",
  "style-src 'self' https: 'unsafe-inline'",
  "connect-src 'self' https: wss:",
  "img-src 'self' https: data: blob:",
  "font-src 'self' https: data:",
  "media-src 'self' https: data: blob:",
  "worker-src 'self' blob:",
  "frame-src 'self' https:",
  "form-action 'self' https:",
  "object-src 'none'",
].join('; ');

function requestHost(req: Request): string {
  const forwardedHost = String(req.headers['x-forwarded-host'] ?? '').split(',')[0]?.trim();
  return String(forwardedHost || req.headers.host || '').split(':')[0].toLowerCase();
}

export function slugFromPublicSiteHost(host: string): string | null {
  const domain = publicSiteDomain().toLowerCase();
  const suffix = `.${domain}`;
  if (!host.endsWith(suffix)) return null;
  const slug = host.slice(0, -suffix.length);
  if (!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(slug)) return null;
  return slug;
}

function contentTypeFor(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case '.html':
      return 'text/html; charset=utf-8';
    case '.js':
      return 'text/javascript; charset=utf-8';
    case '.css':
      return 'text/css; charset=utf-8';
    case '.json':
      return 'application/json; charset=utf-8';
    case '.svg':
      return 'image/svg+xml';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.txt':
      return 'text/plain; charset=utf-8';
    default:
      return 'application/octet-stream';
  }
}

async function sendStaticFile(res: Response, filePath: string): Promise<void> {
  const data = await fs.readFile(filePath);
  res.setHeader('X-Robots-Tag', 'noindex');
  res.setHeader('Content-Security-Policy', GENERATED_SITE_CSP);
  res.setHeader('Content-Type', contentTypeFor(filePath));
  res.setHeader('Cache-Control', path.basename(filePath) === 'index.html' ? HTML_CACHE : LONG_STATIC_CACHE);
  res.send(data);
}

async function serveChannelSiteBySlug(slug: string, req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const site = await getChannelSiteBySlug(slug);
    if (!site || site.latestBuildStatus !== 'succeeded') {
      res.setHeader('X-Robots-Tag', 'noindex');
      res.status(404).send('Site not published');
      return;
    }

    const distRoot = webDistPath(site.userId, site.channelId);
    const rawPath = decodeURIComponent(req.path.split('?')[0] ?? '/');
    const normalized = rawPath === '/' ? 'index.html' : rawPath.replace(/^\/+/, '');
    const safeRelative = normalized.includes('\0') || normalized.split('/').some((part) => part === '..')
      ? 'index.html'
      : normalized;
    const candidate = path.resolve(distRoot, safeRelative);
    const distRootWithSep = `${path.resolve(distRoot)}${path.sep}`;
    const target = candidate === distRoot || candidate.startsWith(distRootWithSep)
      ? candidate
      : path.join(distRoot, 'index.html');

    try {
      const stat = await fs.stat(target);
      if (stat.isFile()) {
        await sendStaticFile(res, target);
        return;
      }
    } catch {
      // Fall through to SPA fallback.
    }

    await sendStaticFile(res, path.join(distRoot, 'index.html'));
  } catch (error) {
    next(error);
  }
}

router.use('/sites/:slug', async (req: Request, res: Response, next: NextFunction) => {
  const slug = String(req.params.slug ?? '').toLowerCase();
  if (!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(slug)) {
    res.status(404).send('Site not found');
    return;
  }
  await serveChannelSiteBySlug(slug, req, res, next);
});

router.use(async (req: Request, res: Response, next: NextFunction) => {
  const slug = slugFromPublicSiteHost(requestHost(req));
  if (!slug) {
    next();
    return;
  }
  await serveChannelSiteBySlug(slug, req, res, next);
});

export default router;
