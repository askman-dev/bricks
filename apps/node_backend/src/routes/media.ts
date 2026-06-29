import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  createImageMediaAsset,
  getMediaAssetForUser,
  mediaAssetToDto,
  resolveMediaAssetPath,
} from '../services/mediaService.js';

const router = express.Router();
router.use(authenticate);

function readString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function sendMediaError(res: Response, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  if (
    message.includes('Unsupported image MIME type') ||
    message.includes('Image data is empty') ||
    message.includes('20MB') ||
    message.includes('Invalid channel-relative path')
  ) {
    res.status(400).json({ error: message });
    return;
  }
  console.error('Media route error:', error);
  res.status(500).json({ error: 'Media request failed' });
}

router.post('/uploads', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const channelId = readString(req.body?.channelId);
    const mimeType = readString(req.body?.mimeType);
    const dataBase64 = readString(req.body?.dataBase64);
    if (!channelId || !mimeType || !dataBase64) {
      res.status(400).json({ error: 'channelId, mimeType, and dataBase64 are required' });
      return;
    }
    const asset = await createImageMediaAsset({
      userId,
      channelId,
      threadId: readString(req.body?.threadId),
      origin: 'user_upload',
      mimeType,
      filename: readString(req.body?.filename) ?? undefined,
      dataBase64,
    });
    res.status(201).json({ media: mediaAssetToDto(asset) });
  } catch (error) {
    sendMediaError(res, error);
  }
});

router.post('/generated-images', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const channelId = readString(req.body?.channelId);
    const mimeType = readString(req.body?.mimeType);
    const dataBase64 = readString(req.body?.dataBase64);
    if (!channelId || !mimeType || !dataBase64) {
      res.status(400).json({ error: 'channelId, mimeType, and dataBase64 are required' });
      return;
    }
    const asset = await createImageMediaAsset({
      userId,
      channelId,
      threadId: readString(req.body?.threadId),
      origin: 'generated_image',
      mimeType,
      filename: readString(req.body?.filename) ?? undefined,
      dataBase64,
      sourceMessageId: readString(req.body?.sourceMessageId),
      provider: readString(req.body?.provider),
      providerOperationName: readString(req.body?.providerOperationName),
      prompt: readString(req.body?.prompt),
    });
    res.status(201).json({ media: mediaAssetToDto(asset) });
  } catch (error) {
    sendMediaError(res, error);
  }
});

async function sendMediaFile(req: AuthRequest, res: Response, download: boolean): Promise<void> {
  const userId = req.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  const mediaId = readString(req.params.mediaId);
  if (!mediaId) {
    res.status(400).json({ error: 'mediaId is required' });
    return;
  }
  const asset = await getMediaAssetForUser(userId, mediaId);
  if (!asset) {
    res.status(404).json({ error: 'Media asset not found' });
    return;
  }
  const absolutePath = await resolveMediaAssetPath(asset);
  res.setHeader('Content-Type', asset.mimeType);
  res.setHeader('Cache-Control', 'private, max-age=60');
  if (download) {
    res.download(absolutePath, asset.filename);
    return;
  }
  res.sendFile(absolutePath);
}

router.get('/:mediaId/preview', async (req: AuthRequest, res: Response) => {
  try {
    await sendMediaFile(req, res, false);
  } catch (error) {
    sendMediaError(res, error);
  }
});

router.get('/:mediaId/content', async (req: AuthRequest, res: Response) => {
  try {
    await sendMediaFile(req, res, false);
  } catch (error) {
    sendMediaError(res, error);
  }
});

router.get('/:mediaId/download', async (req: AuthRequest, res: Response) => {
  try {
    await sendMediaFile(req, res, true);
  } catch (error) {
    sendMediaError(res, error);
  }
});

export default router;
