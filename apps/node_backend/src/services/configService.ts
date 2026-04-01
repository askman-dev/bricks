import crypto from 'crypto';
import pool from '../db/index.js';

// Encryption utilities
const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;

function getEncryptionKey(): Buffer {
  const key = process.env.ENCRYPTION_KEY;
  if (!key) {
    throw new Error('ENCRYPTION_KEY environment variable is not set');
  }
  // Ensure key is exactly 32 bytes for AES-256
  return crypto.createHash('sha256').update(key).digest();
}

function encrypt(text: string): string {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');

  const authTag = cipher.getAuthTag();

  // Format: iv:authTag:encrypted
  return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
}

function decrypt(encryptedText: string): string {
  const key = getEncryptionKey();
  const parts = encryptedText.split(':');

  if (parts.length !== 3) {
    throw new Error('Invalid encrypted text format');
  }

  const iv = Buffer.from(parts[0], 'hex');
  const authTag = Buffer.from(parts[1], 'hex');
  const encrypted = parts[2];

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
}

export interface ApiConfig {
  id: string;
  user_id: string;
  category: string;
  provider: string;
  config: {
    endpoint?: string;
    api_key?: string;
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
      // Merge with existing config so omitted keys (e.g. api_key) are preserved
      const existingConfig = decryptApiConfig(existing.rows[0]).config ?? {};
      const merged = { ...existingConfig, ...updates.config };
      if (updates.config.api_key) {
        merged.api_key = encrypt(updates.config.api_key);
      } else if (typeof existingConfig.api_key === 'string' && existingConfig.api_key.trim()) {
        // Re-encrypt the existing key (decryptApiConfig already decrypted it)
        merged.api_key = encrypt(existingConfig.api_key);
      }
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
    if (typeof cfg.api_key === 'string') {
      try {
        cfg.api_key = decrypt(cfg.api_key);
      } catch (error) {
        console.error('Failed to decrypt API key:', error);
        // Keep encrypted value if decryption fails
      }
    }
  }
  return decrypted;
}
