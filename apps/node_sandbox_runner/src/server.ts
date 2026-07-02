import http, { IncomingMessage, ServerResponse } from 'http';
import type { RunnerConfig } from './config.js';
import { runSandboxCommand, SandboxRunnerError } from './sandboxRunner.js';
import type { RunRequest } from './types.js';

function sendJson(res: ServerResponse, statusCode: number, body: unknown): void {
  res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
      if (Buffer.byteLength(body, 'utf8') > 1024 * 1024) {
        req.destroy(new Error('Request body too large'));
      }
    });
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

function authorized(req: IncomingMessage, config: RunnerConfig): boolean {
  if (!config.token) return true;
  return req.headers.authorization === `Bearer ${config.token}`;
}

function parseRunRequest(value: unknown): RunRequest {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new SandboxRunnerError('Request body must be an object');
  }
  const body = value as Record<string, unknown>;
  if (
    typeof body.userSegment !== 'string' ||
    typeof body.cwd !== 'string' ||
    typeof body.command !== 'string'
  ) {
    throw new SandboxRunnerError('userSegment, cwd, and command are required');
  }
  return {
    userSegment: body.userSegment,
    sandboxRootSegments: Array.isArray(body.sandboxRootSegments)
      ? body.sandboxRootSegments.filter((segment): segment is string => typeof segment === 'string')
      : undefined,
    cwd: body.cwd,
    command: body.command,
    timeoutMs: typeof body.timeoutMs === 'number' ? body.timeoutMs : undefined,
    maxBufferBytes: typeof body.maxBufferBytes === 'number' ? body.maxBufferBytes : undefined,
  };
}

export function createServer(config: RunnerConfig): http.Server {
  return http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
      if (req.method === 'GET' && url.pathname === '/healthz') {
        sendJson(res, 200, { ok: true });
        return;
      }
      if (req.method !== 'POST' || url.pathname !== '/v1/run') {
        sendJson(res, 404, { error: 'not_found' });
        return;
      }
      if (!authorized(req, config)) {
        sendJson(res, 401, { error: 'unauthorized' });
        return;
      }
      const rawBody = await readBody(req);
      const request = parseRunRequest(JSON.parse(rawBody || '{}'));
      const result = await runSandboxCommand(config, request);
      sendJson(res, 200, result);
    } catch (error) {
      const statusCode = error instanceof SandboxRunnerError ? error.statusCode : 500;
      sendJson(res, statusCode, {
        error: error instanceof Error ? error.message : 'Internal server error',
      });
    }
  });
}
