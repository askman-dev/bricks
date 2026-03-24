import express, { Request, Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  createApiConfig,
  getApiConfigs,
  getApiConfig,
  updateApiConfig,
  deleteApiConfig,
} from '../services/configService.js';

const router = express.Router();

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

    // Validate required fields
    if (!category || !provider || !config) {
      res.status(400).json({ error: 'Missing required fields: category, provider, config' });
      return;
    }

    const apiConfig = await createApiConfig(userId, {
      category,
      provider,
      config,
      is_default,
    });

    res.status(201).json(apiConfig);
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

    res.json(configs);
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

    res.json(config);
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
    if (provider !== undefined) updates.provider = provider;
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
    if (is_default !== undefined) updates.is_default = is_default;

    const updatedConfig = await updateApiConfig(userId, id, updates);

    if (!updatedConfig) {
      res.status(404).json({ error: 'Configuration not found' });
      return;
    }

    res.json(updatedConfig);
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
