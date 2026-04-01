import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  createApiConfig,
  getApiConfigs,
  getApiConfig,
  updateApiConfig,
  deleteApiConfig,
} from '../services/configService.js';

const router = express.Router();
const ALLOWED_PROVIDERS = new Set(['anthropic', 'google_ai_studio']);

function maskApiKey(value: string): string {
  if (!value) return value;
  const visible = Math.min(4, value.length);
  return `****${value.slice(value.length - visible)}`;
}

function sanitizeConfigForResponse<T extends { config?: unknown }>(raw: T): T {
  const sanitized: T & { config?: unknown } = { ...raw };
  if (!sanitized.config || typeof sanitized.config !== 'object') {
    return sanitized;
  }
  const config = { ...(sanitized.config as Record<string, unknown>) };
  if (typeof config.api_key === 'string') {
    config.api_key = maskApiKey(config.api_key);
  }
  sanitized.config = config;
  return sanitized;
}

function normalizeIsDefaultValue(
  value: unknown
): { ok: true; value: boolean } | { ok: false } {
  if (typeof value === 'boolean') {
    return { ok: true, value };
  }
  if (typeof value === 'number') {
    if (value === 1) return { ok: true, value: true };
    if (value === 0) return { ok: true, value: false };
    return { ok: false };
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed === '1') return { ok: true, value: true };
    if (trimmed === '0') return { ok: true, value: false };
    if (trimmed.toLowerCase() === 'true') return { ok: true, value: true };
    if (trimmed.toLowerCase() === 'false') return { ok: true, value: false };
    return { ok: false };
  }
  return { ok: false };
}

// All routes require authentication
router.use(authenticate);

/**
 * POST /config
 * Create a new API configuration
 */
router.post('/', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { category, provider, config, is_default } = req.body;
    let normalizedIsDefault: boolean | undefined;
    if (is_default !== undefined) {
      const parsed = normalizeIsDefaultValue(is_default);
      if (!parsed.ok) {
        res.status(400).json({ error: 'Invalid is_default: expected boolean, 0/1, or "true"/"false"' });
        return;
      }
      normalizedIsDefault = parsed.value;
    }

    // Validate required fields
    if (!category || !provider || !config) {
      res.status(400).json({ error: 'Missing required fields: category, provider, config' });
      return;
    }
    if (category === 'llm' && !ALLOWED_PROVIDERS.has(provider)) {
      res.status(400).json({ error: 'Invalid provider' });
      return;
    }

    // Validate config is a plain, non-null object
    if (typeof config !== 'object' || config === null || Array.isArray(config)) {
      res.status(400).json({ error: 'Invalid config: must be a non-null object' });
      return;
    }
    const apiConfig = await createApiConfig(userId, {
      category,
      provider,
      config,
      is_default: normalizedIsDefault,
    });

    res.status(201).json(sanitizeConfigForResponse(apiConfig));
  } catch (error) {
    console.error('Create config error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /config
 * Get all API configurations for the user
 * Optional query parameter: ?category=<category>
 */
router.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const category = req.query.category as string | undefined;

    const configs = await getApiConfigs(userId, category);

    res.json(configs.map(sanitizeConfigForResponse));
  } catch (error) {
    console.error('Get configs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /config/:id
 * Get a specific API configuration
 */
router.get('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;

    const config = await getApiConfig(userId, id);

    if (!config) {
      res.status(404).json({ error: 'Configuration not found' });
      return;
    }

    res.json(sanitizeConfigForResponse(config));
  } catch (error) {
    console.error('Get config error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * PUT /config/:id
 * Update an API configuration
 */
router.put('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const { category, provider, config, is_default } = req.body;

    const updates: {
      category?: string;
      provider?: string;
      config?: Record<string, unknown>;
      is_default?: boolean;
    } = {};

    if (category !== undefined) updates.category = category;
    if (provider !== undefined) {
      let effectiveCategory = category;
      if (effectiveCategory === undefined) {
        // Look up the existing config to determine the effective category
        const existing = await getApiConfig(userId, id);
        if (!existing) {
          res.status(404).json({ error: 'Configuration not found' });
          return;
        }
        effectiveCategory = existing.category;
      }
      if (effectiveCategory === 'llm' && !ALLOWED_PROVIDERS.has(provider)) {
        res.status(400).json({ error: 'Invalid provider' });
        return;
      }
      updates.provider = provider;
    }
    if (config !== undefined) {
      if (
        config === null ||
        typeof config !== 'object' ||
        Array.isArray(config)
      ) {
        res.status(400).json({ error: 'Invalid config: must be an object' });
        return;
      }
      updates.config = config as Record<string, unknown>;
    }
    if (is_default !== undefined) {
      const parsed = normalizeIsDefaultValue(is_default);
      if (!parsed.ok) {
        res.status(400).json({ error: 'Invalid is_default: expected boolean, 0/1, or "true"/"false"' });
        return;
      }
      updates.is_default = parsed.value;
    }

    const updatedConfig = await updateApiConfig(userId, id, updates);

    if (!updatedConfig) {
      res.status(404).json({ error: 'Configuration not found' });
      return;
    }

    res.json(sanitizeConfigForResponse(updatedConfig));
  } catch (error) {
    console.error('Update config error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /config/:id
 * Delete an API configuration
 */
router.delete('/:id', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;

    const deleted = await deleteApiConfig(userId, id);

    if (!deleted) {
      res.status(404).json({ error: 'Configuration not found' });
      return;
    }

    res.json({ message: 'Configuration deleted successfully' });
  } catch (error) {
    console.error('Delete config error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
