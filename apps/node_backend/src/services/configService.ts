import pool from '../db/index.js';
import { decryptSecret, deriveAes256Key, encryptSecret, isEncryptedSecretFormat } from './crypto_utils.js';

function resolveEncryptionKeyMaterial(): string {
  const resolved = process.env.ENCRYPTION_KEY;
  if (typeof resolved === 'string' && resolved.trim().length > 0) {
    return resolved;
  }

  throw new Error('Missing encryption secret: ENCRYPTION_KEY must be set and non-empty.');
}

function getEncryptionKey(): Buffer {
  return deriveAes256Key(resolveEncryptionKeyMaterial());
}

function encrypt(text: string): string {
  return encryptSecret(text, getEncryptionKey());
}

function decrypt(encryptedText: string): string {
  return decryptSecret(encryptedText, getEncryptionKey());
}

export interface ApiConfig {
  id: string;
  user_id: string;
  category: string;
  provider: string;
  config: {
    endpoint?: string;
    api_key?: string;
    api_key_encrypted?: boolean;
    model_preferences?: Record<string, unknown>;
    [key: string]: unknown;
  };
  is_default: boolean;
  created_at: Date;
  updated_at: Date;
}

interface ApiConfigInput {
  category: string;
  provider: string;
  config: ApiConfig['config'];
  is_default?: boolean;
}

// Create API configuration
export async function createApiConfig(
  userId: string,
  input: ApiConfigInput
): Promise<ApiConfig> {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Encrypt sensitive fields
    const configToStore = { ...input.config };
    if (configToStore.api_key) {
      configToStore.api_key = encrypt(configToStore.api_key);
      configToStore.api_key_encrypted = true;
    }

    // If setting as default, unset other defaults in same category
    if (input.is_default) {
      await client.query(
        'UPDATE api_configs SET is_default = FALSE WHERE user_id = $1 AND category = $2',
        [userId, input.category]
      );
    }

    const result = await client.query(
      `INSERT INTO api_configs (user_id, category, provider, config, is_default)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [userId, input.category, input.provider, JSON.stringify(configToStore), input.is_default || false]
    );

    await client.query('COMMIT');

    const config = result.rows[0];

    // Decrypt for response
    return decryptApiConfig(config);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Get API configurations for user
export async function getApiConfigs(
  userId: string,
  category?: string
): Promise<ApiConfig[]> {
  let query = 'SELECT * FROM api_configs WHERE user_id = $1';
  const params: (string | number)[] = [userId];

  if (category) {
    query += ' AND category = $2';
    params.push(category);
  }

  query += ' ORDER BY created_at DESC';

  const result = await pool.query(query, params);

  return result.rows.map(decryptApiConfig);
}

// Get single API configuration
export async function getApiConfig(
  userId: string,
  configId: string
): Promise<ApiConfig | null> {
  const result = await pool.query(
    'SELECT * FROM api_configs WHERE id = $1 AND user_id = $2',
    [configId, userId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  return decryptApiConfig(result.rows[0]);
}

// Update API configuration
export async function updateApiConfig(
  userId: string,
  configId: string,
  updates: Partial<ApiConfigInput>
): Promise<ApiConfig | null> {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Get existing config
    const existing = await client.query(
      'SELECT * FROM api_configs WHERE id = $1 AND user_id = $2',
      [configId, userId]
    );

    if (existing.rows.length === 0) {
      await client.query('ROLLBACK');
      return null;
    }

    // If setting as default, unset other defaults in same category
    if (updates.is_default) {
      const category = updates.category || existing.rows[0].category;
      await client.query(
        'UPDATE api_configs SET is_default = FALSE WHERE user_id = $1 AND category = $2 AND id != $3',
        [userId, category, configId]
      );
    }

    // Build update query
    const updateFields: string[] = [];
    const values: unknown[] = [];
    let paramCount = 1;

    if (updates.category) {
      updateFields.push(`category = $${paramCount++}`);
      values.push(updates.category);
    }

    if (updates.provider) {
      updateFields.push(`provider = $${paramCount++}`);
      values.push(updates.provider);
    }

    if (updates.config) {
      // Use the raw stored JSON for merging rather than the decrypted value.
      // Previously, decryptApiConfig was called here; if decryption failed it set api_key = '',
      // which would then be merged back and written to DB, destroying the stored ciphertext.
      let rawExistingConfig: Record<string, unknown> = {};
      const rawConfigValue = existing.rows[0].config;
      if (typeof rawConfigValue === 'string') {
        try {
          rawExistingConfig = JSON.parse(rawConfigValue) as Record<string, unknown>;
        } catch {
          rawExistingConfig = {};
        }
      } else if (rawConfigValue && typeof rawConfigValue === 'object') {
        rawExistingConfig = rawConfigValue as Record<string, unknown>;
      }

      const merged: Record<string, unknown> = { ...rawExistingConfig, ...(updates.config as Record<string, unknown>) };

      const apiKeySpecifiedInUpdate = Object.prototype.hasOwnProperty.call(
        updates.config as Record<string, unknown>,
        'api_key'
      );
      if (apiKeySpecifiedInUpdate) {
        const newApiKey = (updates.config as { api_key?: unknown }).api_key;
        if (typeof newApiKey === 'string' && newApiKey.trim().length > 0) {
          // Explicit non-empty api_key: encrypt and store
          merged.api_key = encrypt(newApiKey);
          merged.api_key_encrypted = true;
        } else {
          // Explicit clear (empty string, null, undefined): remove api_key
          delete merged.api_key;
          merged.api_key_encrypted = false;
        }
      }
      // No api_key in updates: preserve the existing stored value (encrypted or not) untouched
      updateFields.push(`config = $${paramCount++}`);
      values.push(JSON.stringify(merged));
    }

    if (updates.is_default !== undefined) {
      updateFields.push(`is_default = $${paramCount++}`);
      values.push(updates.is_default);
    }

    if (updateFields.length === 0) {
      await client.query('ROLLBACK');
      return decryptApiConfig(existing.rows[0]);
    }

    values.push(configId, userId);

    const result = await client.query(
      `UPDATE api_configs SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
       WHERE id = $${paramCount++} AND user_id = $${paramCount++}
       RETURNING *`,
      values
    );

    await client.query('COMMIT');

    return decryptApiConfig(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Delete API configuration
export async function deleteApiConfig(
  userId: string,
  configId: string
): Promise<boolean> {
  const result = await pool.query(
    'DELETE FROM api_configs WHERE id = $1 AND user_id = $2',
    [configId, userId]
  );

  return result.rowCount !== null && result.rowCount > 0;
}

// Helper to decrypt API config
function decryptApiConfig<T extends { config?: unknown }>(config: T): T {
  const decrypted: T & { config?: unknown } = { ...config };

  if (typeof decrypted.config === 'string') {
    try {
      decrypted.config = JSON.parse(decrypted.config);
    } catch (error) {
      console.error('Failed to parse config JSON:', error);
      // If parsing fails, leave config as the original string
    }
  }

  if (decrypted.config && typeof decrypted.config === 'object') {
    const cfg = decrypted.config as { [key: string]: unknown };
    const shouldDecrypt =
      cfg.api_key_encrypted === true ||
      (typeof cfg.api_key === 'string' && isEncryptedSecretFormat(cfg.api_key));
    if (typeof cfg.api_key === 'string' && shouldDecrypt) {
      try {
        cfg.api_key = decrypt(cfg.api_key);
        cfg.api_key_encrypted = false;
      } catch (error) {
        console.error('Failed to decrypt API key:', error);
        // Never pass through undecryptable ciphertext as an API key value.
        // This most commonly indicates ENCRYPTION_KEY mismatch across environments.
        cfg.api_key = '';
        cfg.api_key_encrypted = false;
      }
    }
  }
  return decrypted;
}
