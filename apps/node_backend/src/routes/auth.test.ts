import { describe, expect, it, vi } from 'vitest';
import { isAllowedReturnTo } from './auth_return_to.js';

// Mock DB-dependent modules so importing auth.ts does not trigger
// pool initialization (which requires database environment variables).
vi.mock('../services/oauthStateService.js', () => ({
  storeOAuthState: vi.fn(),
  consumeOAuthState: vi.fn(),
}));
vi.mock('../services/userService.js', () => ({
  findOrCreateUserByOAuth: vi.fn(),
  getUserById: vi.fn(),
  getOAuthConnections: vi.fn(),
  deleteUser: vi.fn(),
}));

import {
  buildPostLoginRedirectTarget,
  decodeOAuthState,
  validateOAuthCallbackState,
} from './auth.js';

describe('auth return_to validation', () => {
  it('allows same-origin return_to when it matches callback URL origin', () => {
    expect(
      isAllowedReturnTo('https://bricks.askman.dev/', {
        callbackUrl: 'https://bricks.askman.dev/api/auth/github/callback',
        nodeEnv: 'production',
      })
    ).toBe(true);
  });

  it('rejects non-https return_to for non-localhost origins', () => {
    expect(
      isAllowedReturnTo('http://bricks.askman.dev/', {
        callbackUrl: 'https://bricks.askman.dev/api/auth/github/callback',
        nodeEnv: 'production',
      })
    ).toBe(false);
  });

  it('still allows explicitly configured origins', () => {
    expect(
      isAllowedReturnTo('https://app.askman.dev/dashboard', {
        allowedReturnOrigins: 'https://app.askman.dev, https://example.com',
        nodeEnv: 'production',
      })
    ).toBe(true);
  });
});

/** Encodes a state payload in the base64url JSON format used by the auth flow. */
function encodeStatePayload(nonce: string, returnTo: string): string {
  return Buffer.from(JSON.stringify({ nonce, returnTo }), 'utf8').toString('base64url');
}

describe('decodeOAuthState', () => {
  it('decodes a valid base64url JSON state payload', () => {
    const encoded = encodeStatePayload('abc123', 'https://example.com/');
    expect(decodeOAuthState(encoded)).toEqual({ nonce: 'abc123', returnTo: 'https://example.com/' });
  });

  it('returns null for invalid base64url input', () => {
    expect(decodeOAuthState('not!!valid!!!')).toBeNull();
  });

  it('returns null when nonce field is missing', () => {
    const encoded = Buffer.from(JSON.stringify({ returnTo: 'https://example.com/' }), 'utf8').toString('base64url');
    expect(decodeOAuthState(encoded)).toBeNull();
  });

  it('returns null when returnTo field is missing', () => {
    const encoded = Buffer.from(JSON.stringify({ nonce: 'abc' }), 'utf8').toString('base64url');
    expect(decodeOAuthState(encoded)).toBeNull();
  });

  it('strips unknown extra fields such as the legacy sig field', () => {
    const encoded = Buffer.from(
      JSON.stringify({ nonce: 'n', returnTo: 'https://x.com/', sig: 'oldsig' }),
      'utf8'
    ).toString('base64url');
    const result = decodeOAuthState(encoded);
    expect(result).toEqual({ nonce: 'n', returnTo: 'https://x.com/' });
    expect(Object.keys(result ?? {})).not.toContain('sig');
  });
});

describe('validateOAuthCallbackState', () => {
  it('accepts when cookie nonce matches the state payload nonce', async () => {
    const nonce = 'a'.repeat(64);
    const state = encodeStatePayload(nonce, 'https://example.com/');
    const lookup = vi.fn();

    const result = await validateOAuthCallbackState(state, nonce, lookup);

    expect(result).toEqual({ valid: true, returnTo: 'https://example.com/' });
    expect(lookup).not.toHaveBeenCalled();
  });

  it('rejects when cookie is present but nonce does not match', async () => {
    const state = encodeStatePayload('nonce-in-state', 'https://example.com/');
    const lookup = vi.fn();

    const result = await validateOAuthCallbackState(state, 'different-nonce', lookup);

    expect(result).toEqual({ valid: false });
    expect(lookup).not.toHaveBeenCalled();
  });

  it('does not fall back to DB lookup when cookie present but mismatched', async () => {
    const state = encodeStatePayload('nonce-in-state', 'https://example.com/');
    const lookup = vi.fn().mockResolvedValue('https://example.com/');

    const result = await validateOAuthCallbackState(state, 'wrong-nonce', lookup);

    expect(result).toEqual({ valid: false });
    expect(lookup).not.toHaveBeenCalled();
  });

  it('accepts via DB store when cookie is absent and nonce is found', async () => {
    const nonce = 'testnonce123';
    const state = encodeStatePayload(nonce, 'https://state-returnto.com/');
    const lookup = vi.fn().mockResolvedValue('https://db-returnto.com/');

    const result = await validateOAuthCallbackState(state, undefined, lookup);

    expect(result).toEqual({ valid: true, returnTo: 'https://db-returnto.com/' });
    expect(lookup).toHaveBeenCalledWith(nonce);
  });

  it('uses returnTo from DB, not from state parameter, to prevent open-redirect attacks', async () => {
    const nonce = 'testnonce456';
    const stateWithCraftedReturnTo = encodeStatePayload(nonce, 'https://attacker.com/');
    const lookup = vi.fn().mockResolvedValue('https://legitimate.com/');

    const result = await validateOAuthCallbackState(stateWithCraftedReturnTo, undefined, lookup);

    expect(result).toEqual({ valid: true, returnTo: 'https://legitimate.com/' });
  });

  it('rejects when cookie is absent and nonce not found in server-side store', async () => {
    const state = encodeStatePayload('unknown-nonce', 'https://example.com/');
    const lookup = vi.fn().mockResolvedValue(null);

    const result = await validateOAuthCallbackState(state, undefined, lookup);

    expect(result).toEqual({ valid: false });
  });

  it('accepts legacy plain-hex nonce when cookie is present and matches', async () => {
    const nonce = 'a'.repeat(64); // 64 lowercase hex chars
    const lookup = vi.fn();

    const result = await validateOAuthCallbackState(nonce, nonce, lookup);

    expect(result.valid).toBe(true);
    if (result.valid) {
      // returnTo is the default (localhost in test env where GITHUB_CALLBACK_URL is unset)
      expect(result.returnTo).toBe('http://localhost:3000/');
    }
    expect(lookup).not.toHaveBeenCalled();
  });

  it('rejects legacy plain-hex nonce when cookie does not match', async () => {
    const nonce = 'a'.repeat(64);
    const lookup = vi.fn();

    const result = await validateOAuthCallbackState(nonce, 'b'.repeat(64), lookup);

    expect(result).toEqual({ valid: false });
    expect(lookup).not.toHaveBeenCalled();
  });

  it('rejects legacy plain-hex nonce when cookie is absent', async () => {
    const nonce = 'a'.repeat(64);
    const lookup = vi.fn().mockResolvedValue(null);

    const result = await validateOAuthCallbackState(nonce, undefined, lookup);

    expect(result).toEqual({ valid: false });
  });

  it('treats empty-string cookie as absent and falls through to DB lookup', async () => {
    const nonce = 'testnonce789';
    const state = encodeStatePayload(nonce, 'https://example.com/');
    const lookup = vi.fn().mockResolvedValue('https://db-returnto.com/');

    const result = await validateOAuthCallbackState(state, '', lookup);

    expect(result).toEqual({ valid: true, returnTo: 'https://db-returnto.com/' });
  });

  it('rejects when state parameter is absent', async () => {
    const lookup = vi.fn();

    const result = await validateOAuthCallbackState(undefined, undefined, lookup);

    expect(result).toEqual({ valid: false });
    expect(lookup).not.toHaveBeenCalled();
  });
});

describe('buildPostLoginRedirectTarget', () => {
  it('returns original redirect for same-origin flow', () => {
    const redirect = buildPostLoginRedirectTarget(
      'https://bricks.askman.dev/',
      'jwt-token',
      'https://bricks.askman.dev'
    );
    expect(redirect).toBe('https://bricks.askman.dev/');
  });

  it('appends auth_token fragment for cross-origin flow', () => {
    const redirect = buildPostLoginRedirectTarget(
      'https://bricks-aoqjuy2sr-askman-dev.vercel.app/',
      'jwt-token',
      'https://bricks.askman.dev'
    );
    expect(redirect).toBe('https://bricks-aoqjuy2sr-askman-dev.vercel.app/#auth_token=jwt-token');
  });

  it('preserves existing fragment params when appending auth_token', () => {
    const redirect = buildPostLoginRedirectTarget(
      'https://bricks-aoqjuy2sr-askman-dev.vercel.app/#foo=bar',
      'jwt-token',
      'https://bricks.askman.dev'
    );
    expect(redirect).toContain('#');
    const hash = redirect.split('#')[1] ?? '';
    const params = new URLSearchParams(hash);
    expect(params.get('foo')).toBe('bar');
    expect(params.get('auth_token')).toBe('jwt-token');
  });
});
