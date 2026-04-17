export interface PlatformTokenClaims {
  typ: string;
  pluginId: string;
  userId: string;
  exp?: number;
}

function decodeBase64Url(value: string): string {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  return Buffer.from(padded, 'base64').toString('utf8');
}

function readClaims(token: string): Record<string, unknown> {
  const segments = token.split('.');
  if (segments.length !== 3) {
    throw new Error('BRICKS_PLATFORM_TOKEN must be a JWT with 3 segments');
  }

  try {
    return JSON.parse(decodeBase64Url(segments[1])) as Record<string, unknown>;
  } catch {
    throw new Error('BRICKS_PLATFORM_TOKEN payload is not valid JSON');
  }
}

export function parseAndValidatePlatformTokenClaims(token: string, pluginId: string): PlatformTokenClaims {
  const claims = readClaims(token);
  const typ = typeof claims.typ === 'string' ? claims.typ : '';
  const claimPluginId = typeof claims.pluginId === 'string' ? claims.pluginId : '';
  const userId = typeof claims.userId === 'string' ? claims.userId : '';
  const exp = typeof claims.exp === 'number' ? claims.exp : undefined;

  if (typ !== 'platform_plugin') {
    throw new Error('BRICKS_PLATFORM_TOKEN typ must equal platform_plugin');
  }
  if (!claimPluginId) {
    throw new Error('BRICKS_PLATFORM_TOKEN must include pluginId claim');
  }
  if (claimPluginId !== pluginId) {
    throw new Error('BRICKS_PLATFORM_TOKEN pluginId claim does not match BRICKS_PLUGIN_ID');
  }
  if (!userId) {
    throw new Error('BRICKS_PLATFORM_TOKEN must include userId claim');
  }

  if (exp !== undefined && exp <= Math.floor(Date.now() / 1000)) {
    throw new Error('BRICKS_PLATFORM_TOKEN has expired');
  }

  return { typ, pluginId: claimPluginId, userId, exp };
}
