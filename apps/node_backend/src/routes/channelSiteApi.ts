import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  channelSitePublishStatusDto,
  ChannelSiteError,
  getChannelSitePublishStatus,
} from '../services/channelSiteService.js';

const router = express.Router();
router.use(authenticate);

function readParam(value: unknown, maxLength = 255): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= maxLength ? trimmed : null;
}

function sendSiteError(res: Response, error: unknown): void {
  if (error instanceof ChannelSiteError) {
    res.status(error.statusCode).json({ error: error.message });
    return;
  }
  console.error('Channel site API error:', error);
  res.status(500).json({ error: 'Site request failed' });
}

router.get('/:channelId/publish-status', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    const channelId = readParam(req.params.channelId);
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    if (!channelId) {
      res.status(400).json({ error: 'channelId is required' });
      return;
    }
    const result = await getChannelSitePublishStatus({ userId, channelId });
    res.json(channelSitePublishStatusDto(result.site, result.status));
  } catch (error) {
    sendSiteError(res, error);
  }
});

export default router;
