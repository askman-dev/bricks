import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const AUTH_TAG_LENGTH = 16;
const ENCRYPTION_PREFIX = 'enc:v1:';
const LEGACY_REGEX = /^[a-f0-9]{32}:[a-f0-9]{32}:[a-f0-9]+$/i;
const HEX_REGEX = /^[0-9a-fA-F]+$/;

export function deriveAes256Key(keyMaterial: string): Buffer {
  return crypto.createHash('sha256').update(keyMaterial).digest();
}

export function isEncryptedSecretFormat(value: string): boolean {
  return value.startsWith(ENCRYPTION_PREFIX) || LEGACY_REGEX.test(value);
}

export function encryptSecret(plainText: string, key: Buffer): string {
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plainText, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag();

  return `${ENCRYPTION_PREFIX}${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
}

export function decryptSecret(encryptedText: string, key: Buffer): string {
  const normalized = encryptedText.startsWith(ENCRYPTION_PREFIX)
    ? encryptedText.slice(ENCRYPTION_PREFIX.length)
    : encryptedText;
  const parts = normalized.split(':');
  if (parts.length !== 3) {
    throw new Error('Invalid encrypted text format');
  }

  const [ivHex, authTagHex, encrypted] = parts;

  if (!HEX_REGEX.test(ivHex) || ivHex.length !== IV_LENGTH * 2) {
    throw new Error('Invalid encrypted text format: malformed IV');
  }
  if (!HEX_REGEX.test(authTagHex) || authTagHex.length !== AUTH_TAG_LENGTH * 2) {
    throw new Error('Invalid encrypted text format: malformed auth tag');
  }

  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
}
