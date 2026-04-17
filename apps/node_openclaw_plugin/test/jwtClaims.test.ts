import { describe, expect, it } from 'vitest';
import { parseAndValidatePlatformTokenClaims } from '../src/jwtClaims.js';

function makeJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.signature`;
}

describe('parseAndValidatePlatformTokenClaims', () => {
  it('parses required claims', () => {
    const token = makeJwt({
      typ: 'platform_plugin',
      pluginId: 'plugin_local_main',
      userId: 'user_1',
      exp: Math.floor(Date.now() / 1000) + 3600,
    });

    const claims = parseAndValidatePlatformTokenClaims(token, 'plugin_local_main');
    expect(claims.userId).toBe('user_1');
  });

  it('rejects plugin mismatch and missing required claims', () => {
    const mismatchPlugin = makeJwt({ typ: 'platform_plugin', pluginId: 'another_plugin', userId: 'user_1' });
    expect(() => parseAndValidatePlatformTokenClaims(mismatchPlugin, 'plugin_local_main')).toThrow(
      'pluginId claim does not match BRICKS_PLUGIN_ID',
    );

    const missingUser = makeJwt({ typ: 'platform_plugin', pluginId: 'plugin_local_main' });
    expect(() => parseAndValidatePlatformTokenClaims(missingUser, 'plugin_local_main')).toThrow(
      'must include userId claim',
    );
  });
});
