import { describe, expect, it } from 'vitest';
import { isAllowedReturnTo } from './auth_return_to.js';

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
