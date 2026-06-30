import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const { poolMock, resolveRuntimeConfigForUserMock, mediaMocks, readFileMock } = vi.hoisted(() => ({
  poolMock: {
    query: vi.fn(),
  },
  resolveRuntimeConfigForUserMock: vi.fn(),
  mediaMocks: {
    createImageMediaAsset: vi.fn(),
    createVideoMediaAsset: vi.fn(),
    getMediaAssetForUser: vi.fn(),
    mediaAssetToDto: vi.fn((asset: Record<string, unknown>) => ({ id: asset.id, kind: asset.kind })),
    resolveMediaAssetPath: vi.fn(),
  },
  readFileMock: vi.fn(),
}));

vi.mock('../db/index.js', () => ({
  default: poolMock,
}));

vi.mock('../llm/llm_service.js', () => ({
  resolveRuntimeConfigForUser: resolveRuntimeConfigForUserMock,
}));

vi.mock('./mediaService.js', () => mediaMocks);

vi.mock('fs/promises', () => ({
  readFile: readFileMock,
}));

function jobRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 'job-1',
    user_id: 'user-1',
    channel_id: 'default',
    thread_id: null,
    kind: 'image',
    status: 'running',
    prompt: 'make an image',
    input_media_ids: '[]',
    provider: 'google_ai_studio',
    model: 'gemini-3.1-flash-image',
    provider_operation_name: null,
    result_media_id: null,
    error_text: null,
    created_at: '2026-06-30T00:00:00.000Z',
    updated_at: '2026-06-30T00:00:00.000Z',
    ...overrides,
  };
}

function mediaAsset(overrides: Record<string, unknown> = {}) {
  return {
    id: 'media-1',
    userId: 'user-1',
    channelId: 'default',
    threadId: null,
    kind: 'image',
    origin: 'user_upload',
    status: 'ready',
    mimeType: 'image/png',
    filename: 'image.png',
    channelRelativePath: 'media/uploads/media-1.png',
    thumbnailChannelRelativePath: null,
    sizeBytes: 10,
    width: null,
    height: null,
    durationMs: null,
    sourceMessageId: null,
    provider: null,
    providerOperationName: null,
    prompt: null,
    errorText: null,
    createdAt: '2026-06-30T00:00:00.000Z',
    updatedAt: '2026-06-30T00:00:00.000Z',
    ...overrides,
  };
}

describe('mediaGenerationService', () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    poolMock.query.mockReset();
    resolveRuntimeConfigForUserMock.mockReset();
    mediaMocks.createImageMediaAsset.mockReset();
    mediaMocks.createVideoMediaAsset.mockReset();
    mediaMocks.getMediaAssetForUser.mockReset();
    mediaMocks.mediaAssetToDto.mockClear();
    mediaMocks.resolveMediaAssetPath.mockReset();
    readFileMock.mockReset();
    resolveRuntimeConfigForUserMock.mockResolvedValue({
      provider: 'google_ai_studio',
      baseUrl: 'https://generativelanguage.googleapis.com',
      apiKey: 'gemini-key',
      defaultModel: 'gemini-flash-latest',
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('generates an image with text and reference image parts', async () => {
    poolMock.query
      .mockResolvedValueOnce({ rows: [jobRow({ input_media_ids: '["ref-1"]' })] })
      .mockResolvedValueOnce({
        rows: [
          jobRow({
            status: 'succeeded',
            provider_operation_name: 'interaction-1',
            result_media_id: 'generated-1',
            input_media_ids: '["ref-1"]',
          }),
        ],
      });
    mediaMocks.getMediaAssetForUser.mockResolvedValue(mediaAsset({ id: 'ref-1' }));
    mediaMocks.resolveMediaAssetPath.mockResolvedValue('/tmp/ref.png');
    readFileMock.mockResolvedValue(Buffer.from('reference-image'));
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          id: 'interaction-1',
          output_image: {
            data: Buffer.from('generated-image').toString('base64'),
            mime_type: 'image/png',
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
    mediaMocks.createImageMediaAsset.mockResolvedValue(
      mediaAsset({ id: 'generated-1', origin: 'generated_image' }),
    );

    const { generateImageMedia } = await import('./mediaGenerationService.js');
    const result = await generateImageMedia({
      userId: 'user-1',
      channelId: 'default',
      prompt: 'make an image',
      referenceMediaIds: ['ref-1'],
    });

    expect(result.job.status).toBe('succeeded');
    expect(fetchMock).toHaveBeenCalledWith(
      'https://generativelanguage.googleapis.com/v1beta/interactions',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({ 'x-goog-api-key': 'gemini-key' }),
      }),
    );
    const body = JSON.parse(fetchMock.mock.calls[0][1].body as string);
    expect(body).toMatchObject({
      model: 'gemini-3.1-flash-image',
      input: [
        { type: 'text', text: 'make an image' },
        {
          type: 'image',
          mime_type: 'image/png',
          data: Buffer.from('reference-image').toString('base64'),
        },
      ],
    });
    expect(mediaMocks.createImageMediaAsset).toHaveBeenCalledWith(
      expect.objectContaining({
        origin: 'generated_image',
        provider: 'google_ai_studio',
        providerOperationName: 'interaction-1',
      }),
    );
  });

  it('starts a Veo video job with up to three referenceImages', async () => {
    poolMock.query
      .mockResolvedValueOnce({
        rows: [
          jobRow({
            kind: 'video',
            model: 'veo-3.1-generate-preview',
            input_media_ids: '["ref-1","ref-2"]',
          }),
        ],
      })
      .mockResolvedValueOnce({
        rows: [
          jobRow({
            kind: 'video',
            model: 'veo-3.1-generate-preview',
            provider_operation_name: 'operations/video-1',
            input_media_ids: '["ref-1","ref-2"]',
          }),
        ],
      });
    mediaMocks.getMediaAssetForUser.mockImplementation(async (_userId: string, mediaId: string) =>
      mediaAsset({ id: mediaId, channelRelativePath: `media/uploads/${mediaId}.png` }),
    );
    mediaMocks.resolveMediaAssetPath.mockImplementation(async (asset: { id: string }) => `/tmp/${asset.id}.png`);
    readFileMock.mockImplementation(async (filePath: string) => Buffer.from(filePath));
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ name: 'operations/video-1' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const { startVideoGenerationJob } = await import('./mediaGenerationService.js');
    const job = await startVideoGenerationJob({
      userId: 'user-1',
      channelId: 'default',
      prompt: 'cinematic product shot',
      referenceMediaIds: ['ref-1', 'ref-2'],
    });

    expect(job.providerOperationName).toBe('operations/video-1');
    expect(fetchMock).toHaveBeenCalledWith(
      'https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-generate-preview:predictLongRunning',
      expect.objectContaining({ method: 'POST' }),
    );
    const body = JSON.parse(fetchMock.mock.calls[0][1].body as string);
    expect(body.instances[0].referenceImages).toEqual([
      {
        image: {
          inlineData: {
            mimeType: 'image/png',
            data: Buffer.from('/tmp/ref-1.png').toString('base64'),
          },
        },
        referenceType: 'asset',
      },
      {
        image: {
          inlineData: {
            mimeType: 'image/png',
            data: Buffer.from('/tmp/ref-2.png').toString('base64'),
          },
        },
        referenceType: 'asset',
      },
    ]);
    expect(body.parameters.durationSeconds).toBe('8');
  });

  it('downloads a completed Veo operation into a generated video media asset', async () => {
    poolMock.query
      .mockResolvedValueOnce({
        rows: [
          jobRow({
            kind: 'video',
            model: 'veo-3.1-generate-preview',
            prompt: 'make a video',
            provider_operation_name: 'operations/video-1',
          }),
        ],
      })
      .mockResolvedValueOnce({
        rows: [
          jobRow({
            kind: 'video',
            status: 'succeeded',
            model: 'veo-3.1-generate-preview',
            provider_operation_name: 'operations/video-1',
            result_media_id: 'video-1',
          }),
        ],
      });
    fetchMock
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            done: true,
            response: {
              generateVideoResponse: {
                generatedSamples: [
                  { video: { uri: 'https://files.example/video.mp4' } },
                ],
              },
            },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      )
      .mockResolvedValueOnce(
        new Response(Buffer.from('mp4-data'), {
          status: 200,
          headers: { 'Content-Type': 'video/mp4' },
        }),
      );
    mediaMocks.createVideoMediaAsset.mockResolvedValue(
      mediaAsset({
        id: 'video-1',
        kind: 'video',
        origin: 'generated_video',
        mimeType: 'video/mp4',
      }),
    );

    const { refreshVideoGenerationJobForUser } = await import('./mediaGenerationService.js');
    const result = await refreshVideoGenerationJobForUser({
      userId: 'user-1',
      jobId: 'job-1',
    });

    expect(result.job.status).toBe('succeeded');
    expect(fetchMock.mock.calls[0][0]).toBe(
      'https://generativelanguage.googleapis.com/v1beta/operations/video-1',
    );
    expect(fetchMock.mock.calls[1][0]).toBe('https://files.example/video.mp4');
    expect(mediaMocks.createVideoMediaAsset).toHaveBeenCalledWith(
      expect.objectContaining({
        origin: 'generated_video',
        mimeType: 'video/mp4',
        data: Buffer.from('mp4-data'),
        providerOperationName: 'operations/video-1',
      }),
    );
  });
});
