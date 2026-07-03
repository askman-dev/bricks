import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  createImageMediaAsset,
  getMediaAssetForUser,
  mediaAssetToDto,
  resolveMediaAssetPath,
} from '../services/mediaService.js';
import {
  generateImageMedia,
  getMediaGenerationJobForUser,
  mediaGenerationJobToDto,
  MediaGenerationError,
  refreshVideoGenerationJobForUser,
  startVideoGenerationJob,
} from '../services/mediaGenerationService.js';

const router = express.Router();
router.use(authenticate);

function readString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function readStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter(Boolean);
}

function readPositiveInteger(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  const integer = Math.trunc(value);
  return integer > 0 ? integer : null;
}

function sendMediaError(res: Response, error: unknown): void {
  if (error instanceof MediaGenerationError) {
    res.status(error.statusCode).json({ error: error.message });
    return;
  }
  const message = error instanceof Error ? error.message : String(error);
  if (
    message.includes('Unsupported image MIME type') ||
    message.includes('Unsupported video MIME type') ||
    message.includes('Image data is empty') ||
    message.includes('Video data is empty') ||
    message.includes('20MB') ||
    message.includes('512MB') ||
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

router.post('/image-generations', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const channelId = readString(req.body?.channelId);
    const prompt = readString(req.body?.prompt);
    if (!channelId || !prompt) {
      res.status(400).json({ error: 'channelId and prompt are required' });
      return;
    }
    const { job, media } = await generateImageMedia({
      userId,
      channelId,
      threadId: readString(req.body?.threadId),
      prompt,
      referenceMediaIds: readStringArray(req.body?.referenceMediaIds),
      model: readString(req.body?.model),
      configId: readString(req.body?.configId),
    });
    res.status(201).json({
      job: mediaGenerationJobToDto(job, media),
      media: mediaAssetToDto(media),
    });
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

router.post('/video-generations', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const channelId = readString(req.body?.channelId);
    const prompt = readString(req.body?.prompt);
    if (!channelId || !prompt) {
      res.status(400).json({ error: 'channelId and prompt are required' });
      return;
    }
    const job = await startVideoGenerationJob({
      userId,
      channelId,
      threadId: readString(req.body?.threadId),
      prompt,
      referenceMediaIds: readStringArray(req.body?.referenceMediaIds),
      firstFrameMediaId: readString(req.body?.firstFrameMediaId),
      lastFrameMediaId: readString(req.body?.lastFrameMediaId),
      aspectRatio: readString(req.body?.aspectRatio),
      durationSeconds: readPositiveInteger(req.body?.durationSeconds),
      resolution: readString(req.body?.resolution),
      model: readString(req.body?.model),
      configId: readString(req.body?.configId),
    });
    res.status(202).json({ job: mediaGenerationJobToDto(job) });
  } catch (error) {
    sendMediaError(res, error);
  }
});

router.get('/generation-jobs/:jobId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const jobId = readString(req.params.jobId);
    if (!jobId) {
      res.status(400).json({ error: 'jobId is required' });
      return;
    }
    const shouldRefresh = req.query.refresh !== 'false';
    if (shouldRefresh) {
      const { job, media } = await refreshVideoGenerationJobForUser({
        userId,
        jobId,
        configId: readString(req.query.configId),
      });
      res.json({ job: mediaGenerationJobToDto(job, media), media: media ? mediaAssetToDto(media) : null });
      return;
    }
    const job = await getMediaGenerationJobForUser(userId, jobId);
    if (!job) {
      res.status(404).json({ error: 'Media generation job not found' });
      return;
    }
    const media = job.resultMediaId ? await getMediaAssetForUser(userId, job.resultMediaId) : null;
    res.json({ job: mediaGenerationJobToDto(job, media), media: media ? mediaAssetToDto(media) : null });
  } catch (error) {
    sendMediaError(res, error);
  }
});

router.post('/generation-jobs/:jobId/poll', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const jobId = readString(req.params.jobId);
    if (!jobId) {
      res.status(400).json({ error: 'jobId is required' });
      return;
    }
    const { job, media } = await refreshVideoGenerationJobForUser({
      userId,
      jobId,
      configId: readString(req.body?.configId),
    });
    res.json({ job: mediaGenerationJobToDto(job, media), media: media ? mediaAssetToDto(media) : null });
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
