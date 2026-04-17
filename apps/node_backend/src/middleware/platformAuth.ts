import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';

export interface PlatformAuthRequest extends Request {
  platformPluginId?: string;
  platformScopes?: Set<string>;
  platformUserId?: string;
}

interface PlatformJwtPayload {
  typ?: string;
  userId?: string;
  pluginId?: string;
  scopes?: string[];
  iat?: number;
  exp?: number;
}

function parseScopes(raw: string | undefined): Set<string> {
  const fallback = 'events:read,events:ack,messages:write,conversations:read';
  return new Set(
    (raw ?? fallback)
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0),
  );
}

function requestId(): string {
  return `req_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.trim().length === 0) {
    throw new Error('JWT_SECRET environment variable is not set');
  }
  return secret;
}

export function issuePlatformAccessToken(params: {
  userId: string;
  pluginId: string;
  scopes?: string[];
  expiresIn?: string;
}): string {
  const pluginId = params.pluginId.trim();
  if (!pluginId) {
    throw new Error('pluginId is required');
  }
  const payload: PlatformJwtPayload = {
    typ: 'platform_plugin',
    userId: params.userId,
    pluginId,
    scopes: params.scopes,
  };
  return jwt.sign(payload, getJwtSecret(), {
    expiresIn: (params.expiresIn ?? '30d') as any,
  });
}

function sendAuthError(res: Response, code: number, errorCode: string, message: string): void {
  res.status(code).json({
    error: {
      code: errorCode,
      message,
      retryable: false,
    },
    requestId: requestId(),
  });
}

export function authenticatePlatformApiKey(
  req: PlatformAuthRequest,
  res: Response,
  next: NextFunction,
): void {
  const configuredKey = process.env.BRICKS_PLATFORM_API_KEY?.trim();

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    sendAuthError(res, 401, 'UNAUTHORIZED', 'missing bearer token');
    return;
  }

  const token = authHeader.slice(7).trim();
  if (!token) {
    sendAuthError(res, 401, 'UNAUTHORIZED', 'invalid api key');
    return;
  }

  const pluginIdHeader = req.header('X-Bricks-Plugin-Id')?.trim();
  if (!pluginIdHeader) {
    sendAuthError(res, 400, 'MISSING_PLUGIN_ID', 'X-Bricks-Plugin-Id header is required');
    return;
  }

  let scopedUserId: string | undefined;
  let tokenScopes: string[] | undefined;
  if (configuredKey && token === configuredKey) {
    // Static key mode (environment-level shared token).
  } else {
    try {
      const payload = jwt.verify(token, getJwtSecret()) as PlatformJwtPayload;
      if (
        payload.typ !== 'platform_plugin' ||
        !payload.userId ||
        !payload.pluginId ||
        payload.pluginId.trim().length === 0
      ) {
        sendAuthError(res, 401, 'UNAUTHORIZED', 'invalid platform token payload');
        return;
      }
      if (payload.pluginId !== pluginIdHeader) {
        sendAuthError(res, 403, 'FORBIDDEN', 'token pluginId does not match header');
        return;
      }
      scopedUserId = payload.userId;
      tokenScopes = Array.isArray(payload.scopes) ? payload.scopes : undefined;
    } catch (error) {
      if (error instanceof Error && error.message === 'JWT_SECRET environment variable is not set') {
        sendAuthError(res, 500, 'CONFIGURATION_ERROR', 'server authentication is not configured');
        return;
      }
      sendAuthError(res, 401, 'UNAUTHORIZED', 'invalid bearer token');
      return;
    }
  }

  req.platformPluginId = pluginIdHeader;
  req.platformScopes = tokenScopes
    ? new Set(tokenScopes)
    : parseScopes(process.env.BRICKS_PLATFORM_API_SCOPES);
  req.platformUserId = scopedUserId;
  next();
}

export function requirePlatformScope(scope: string) {
  return (req: PlatformAuthRequest, res: Response, next: NextFunction): void => {
    const scopes = req.platformScopes;
    if (!scopes || !scopes.has(scope)) {
      sendAuthError(res, 403, 'FORBIDDEN', `token lacks ${scope}`);
      return;
    }
    next();
  };
}
