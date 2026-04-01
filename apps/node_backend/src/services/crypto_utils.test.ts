import { describe, expect, it } from 'vitest';
import {
  decryptSecret,
  deriveAes256Key,
  encryptSecret,
  isEncryptedSecretFormat,
} from './crypto_utils.js';

describe('crypto_utils', () => {
  it('encrypts and decrypts with the same key material', () => {
    const key = deriveAes256Key('local-dev-key');
    const cipher = encryptSecret('AIzaSyExampleKey', key);
    expect(cipher.startsWith('enc:v1:')).toBe(true);
    const plain = decryptSecret(cipher, key);
    expect(plain).toBe('AIzaSyExampleKey');
  });

  it('fails decryption when key material differs', () => {
    const writeKey = deriveAes256Key('writer-key');
    const readKey = deriveAes256Key('reader-key');
    const cipher = encryptSecret('AIzaSyExampleKey', writeKey);
    expect(() => decryptSecret(cipher, readKey)).toThrow();
  });

  it('recognizes the stored encrypted format iv:tag:cipher', () => {
    expect(
      isEncryptedSecretFormat(
        'enc:v1:03a4a588af11646520930d9ad2d1f645:85776f4f0c04b6dc81e2f6039e9ac670:cab4'
      )
    ).toBe(true);
    expect(
      isEncryptedSecretFormat(
        '03a4a588af11646520930d9ad2d1f645:85776f4f0c04b6dc81e2f6039e9ac670:cab4'
      )
    ).toBe(true);
    expect(isEncryptedSecretFormat('AIzaSyC8xbENuUiTcZulxbMbZ4LLcx-0v-45Cr4')).toBe(false);
  });
});
