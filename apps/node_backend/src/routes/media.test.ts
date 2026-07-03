import express from 'express';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const {
  generateImageMediaMock,
  startVideoGenerationJobMock,
  getMediaGenerationJobForUserMock,
  refreshVideoGenerationJobForUserMock,
  mediaGenerationJobToDtoMock,
  mediaAssetToDtoMock,
} = vi.hoisted(() => ({
  generateImageMediaMock: vi.fn(),
  startVideoGenerationJobMock: vi.fn(),
  getMediaGenerationJobForUserMock: vi.fn(),
  refreshVideoGenerationJobForUserMock: vi.fn(),
  mediaGenerationJobToDtoMock: vi.fn((job: Record<string, unknown>, media?: Record<string, unknown> | null) => ({
    id: job.id,
    kind: job.kind,
    status: job.status,
    resultMediaId: media?.id ?? job.resultMediaId ?? null,
  })),
  mediaAssetToDtoMock: vi.fn((media: Record<string, unknown>) => ({
    id: media.id,
    kind: media.kind,
    previewUrl: `/api/media/${media.id}/preview`,
  })),
}));

vi.mock('../middleware/auth.js', () => ({
  authenticate: (req: express.Request, _res: express.Response, next: express.NextFunction) => {
    (req as express.Request & { userId?: string }).userId = 'user-123';
    next();
  },
}));

vi.mock('../services/mediaGenerationService.js', () => {
  class MockMediaGenerationError extends Error {
    constructor(message: string, readonly statusCode = 400) {
      super(message);
      this.name = 'MediaGenerationError';
    }
  }
  return {
    generateImageMedia: generateImageMediaMock,
    startVideoGenerationJob: startVideoGenerationJobMock,
    getMediaGenerationJobForUser: getMediaGenerationJobForUserMock,
    refreshVideoGenerationJobForUser: refreshVideoGenerationJobForUserMock,
    mediaGenerationJobToDto: mediaGenerationJobToDtoMock,
    MediaGenerationError: MockMediaGenerationError,
  };
});

vi.mock('../services/mediaService.js', () => ({
  createImageMediaAsset: vi.fn(),
  getMediaAssetForUser: vi.fn(),
  mediaAssetToDto: mediaAssetToDtoMock,
  resolveMediaAssetPath: vi.fn(),
}));

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';

beforeAll(async () => {
  const app = express();
  app.use(express.json({ limit: '5mb' }));
  const { default: mediaRoutes } = await import('./media.js');
  app.use('/api/media', mediaRoutes);

  await new Promise<void>((resolve) => {
    server = app.listen(0, '127.0.0.1', () => {
      const address = server?.address();
      if (address && typeof address === 'object') {
        baseUrl = `http://127.0.0.1:${address.port}`;
      }
      resolve();
    });
  });
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) => {
    if (!server) return resolve();
    server.close((err) => (err ? reject(err) : resolve()));
  });
});

describe('media routes', () => {
  beforeEach(() => {
    generateImageMediaMock.mockReset();
    startVideoGenerationJobMock.mockReset();
    getMediaGenerationJobForUserMock.mockReset();
    refreshVideoGenerationJobForUserMock.mockReset();
    mediaGenerationJobToDtoMock.mockClear();
    mediaAssetToDtoMock.mockClear();
  });

  it('creates a provider-side image generation and returns the generated media', async () => {
    generateImageMediaMock.mockResolvedValue({
      job: { id: 'job-1', kind: 'image', status: 'succeeded', resultMediaId: 'media-1' },
      media: { id: 'media-1', kind: 'image' },
    });

    const response = await fetch(`${baseUrl}/api/media/image-generations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        channelId: 'default',
        threadId: 'thread-1',
        prompt: 'Make a tiny studio photo',
        referenceMediaIds: ['image-1'],
      }),
    });

    expect(response.status).toBe(201);
    expect(generateImageMediaMock).toHaveBeenCalledWith({
      userId: 'user-123',
      channelId: 'default',
      threadId: 'thread-1',
      prompt: 'Make a tiny studio photo',
      referenceMediaIds: ['image-1'],
      model: null,
      configId: null,
    });
    const body = (await response.json()) as {
      media?: { id?: string; previewUrl?: string };
    };
    expect(body.media).toEqual(
      expect.objectContaining({ id: 'media-1', previewUrl: '/api/media/media-1/preview' }),
    );
  });

  it('starts a provider-side video generation job', async () => {
    startVideoGenerationJobMock.mockResolvedValue({
      id: 'job-video-1',
      kind: 'video',
      status: 'running',
      resultMediaId: null,
    });

    const response = await fetch(`${baseUrl}/api/media/video-generations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        channelId: 'default',
        prompt: 'A product turntable video',
        referenceMediaIds: ['image-1', 'image-2'],
        durationSeconds: 8,
        aspectRatio: '16:9',
      }),
    });

    expect(response.status).toBe(202);
    expect(startVideoGenerationJobMock).toHaveBeenCalledWith({
      userId: 'user-123',
      channelId: 'default',
      threadId: null,
      prompt: 'A product turntable video',
      referenceMediaIds: ['image-1', 'image-2'],
      firstFrameMediaId: null,
      lastFrameMediaId: null,
      aspectRatio: '16:9',
      durationSeconds: 8,
      resolution: null,
      model: null,
      configId: null,
    });
    const body = (await response.json()) as {
      job?: { id?: string; status?: string };
    };
    expect(body.job).toEqual(
      expect.objectContaining({ id: 'job-video-1', status: 'running' }),
    );
  });

  it('returns cached generation job state when refresh is false', async () => {
    getMediaGenerationJobForUserMock.mockResolvedValue({
      id: 'job-video-1',
      kind: 'video',
      status: 'running',
      resultMediaId: null,
    });

    const response = await fetch(`${baseUrl}/api/media/generation-jobs/job-video-1?refresh=false`);

    expect(response.status).toBe(200);
    expect(getMediaGenerationJobForUserMock).toHaveBeenCalledWith('user-123', 'job-video-1');
    expect(refreshVideoGenerationJobForUserMock).not.toHaveBeenCalled();
  });
});
