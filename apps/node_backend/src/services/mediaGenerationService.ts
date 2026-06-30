import { readFile } from 'fs/promises';
import pool from '../db/index.js';
import { resolveRuntimeConfigForUser } from '../llm/llm_service.js';
import type { LlmRuntimeConfig } from '../llm/types.js';
import {
  createImageMediaAsset,
  createVideoMediaAsset,
  getMediaAssetForUser,
  mediaAssetToDto,
  resolveMediaAssetPath,
  type MediaAsset,
} from './mediaService.js';

export const GEMINI_IMAGE_GENERATION_MODEL = 'gemini-3.1-flash-image';
export const GEMINI_VIDEO_GENERATION_MODEL = 'veo-3.1-generate-preview';

export type MediaGenerationKind = 'image' | 'video';
export type MediaGenerationStatus = 'pending' | 'running' | 'succeeded' | 'failed';

export interface MediaGenerationJob {
  id: string;
  userId: string;
  channelId: string;
  threadId: string | null;
  kind: MediaGenerationKind;
  status: MediaGenerationStatus;
  prompt: string;
  inputMediaIds: string[];
  provider: string;
  model: string;
  providerOperationName: string | null;
  resultMediaId: string | null;
  errorText: string | null;
  createdAt: string;
  updatedAt: string;
}

interface MediaGenerationJobRow {
  id: string;
  user_id: string;
  channel_id: string;
  thread_id: string | null;
  kind: MediaGenerationKind;
  status: MediaGenerationStatus;
  prompt: string;
  input_media_ids: unknown;
  provider: string;
  model: string;
  provider_operation_name: string | null;
  result_media_id: string | null;
  error_text: string | null;
  created_at: string;
  updated_at: string;
}

export class MediaGenerationError extends Error {
  constructor(
    message: string,
    readonly statusCode = 400,
  ) {
    super(message);
    this.name = 'MediaGenerationError';
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function parseInputMediaIds(value: unknown): string[] {
  const parsed =
    typeof value === 'string'
      ? (() => {
          try {
            return JSON.parse(value) as unknown;
          } catch {
            return [];
          }
        })()
      : value;
  if (!Array.isArray(parsed)) return [];
  return parsed.filter((item): item is string => typeof item === 'string');
}

function toMediaGenerationJob(row: MediaGenerationJobRow): MediaGenerationJob {
  return {
    id: row.id,
    userId: row.user_id,
    channelId: row.channel_id,
    threadId: row.thread_id,
    kind: row.kind,
    status: row.status,
    prompt: row.prompt,
    inputMediaIds: parseInputMediaIds(row.input_media_ids),
    provider: row.provider,
    model: row.model,
    providerOperationName: row.provider_operation_name,
    resultMediaId: row.result_media_id,
    errorText: row.error_text,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function mediaGenerationJobToDto(
  job: MediaGenerationJob,
  resultMedia?: MediaAsset | null,
) {
  return {
    id: job.id,
    kind: job.kind,
    status: job.status,
    prompt: job.prompt,
    inputMediaIds: job.inputMediaIds,
    provider: job.provider,
    model: job.model,
    providerOperationName: job.providerOperationName,
    resultMediaId: job.resultMediaId,
    resultMedia: resultMedia ? mediaAssetToDto(resultMedia) : null,
    errorText: job.errorText,
    channelId: job.channelId,
    threadId: job.threadId,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
  };
}

async function createMediaGenerationJob(params: {
  userId: string;
  channelId: string;
  threadId?: string | null;
  kind: MediaGenerationKind;
  status: MediaGenerationStatus;
  prompt: string;
  inputMediaIds?: string[];
  provider: string;
  model: string;
}): Promise<MediaGenerationJob> {
  const result = await pool.query<MediaGenerationJobRow>(
    `INSERT INTO media_generation_jobs (
        user_id,
        channel_id,
        thread_id,
        kind,
        status,
        prompt,
        input_media_ids,
        provider,
        model
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      RETURNING *`,
    [
      params.userId,
      params.channelId,
      params.threadId ?? null,
      params.kind,
      params.status,
      params.prompt,
      JSON.stringify(params.inputMediaIds ?? []),
      params.provider,
      params.model,
    ],
  );
  return toMediaGenerationJob(result.rows[0]);
}

async function updateMediaGenerationJob(
  jobId: string,
  updates: {
    status?: MediaGenerationStatus;
    providerOperationName?: string | null;
    resultMediaId?: string | null;
    errorText?: string | null;
  },
): Promise<MediaGenerationJob> {
  const result = await pool.query<MediaGenerationJobRow>(
    `UPDATE media_generation_jobs
       SET status = COALESCE($2, status),
           provider_operation_name = COALESCE($3, provider_operation_name),
           result_media_id = COALESCE($4, result_media_id),
           error_text = $5,
           updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [
      jobId,
      updates.status ?? null,
      updates.providerOperationName ?? null,
      updates.resultMediaId ?? null,
      updates.errorText ?? null,
    ],
  );
  return toMediaGenerationJob(result.rows[0]);
}

export async function getMediaGenerationJobForUser(
  userId: string,
  jobId: string,
): Promise<MediaGenerationJob | null> {
  const result = await pool.query<MediaGenerationJobRow>(
    `SELECT * FROM media_generation_jobs WHERE user_id = $1 AND id = $2 LIMIT 1`,
    [userId, jobId],
  );
  return result.rows[0] ? toMediaGenerationJob(result.rows[0]) : null;
}

async function resolveGoogleConfig(
  userId: string,
  configId?: string,
): Promise<LlmRuntimeConfig> {
  try {
    return await resolveRuntimeConfigForUser(userId, 'google_ai_studio', configId);
  } catch (error) {
    throw new MediaGenerationError(
      error instanceof Error ? error.message : 'Google AI Studio configuration is required',
      400,
    );
  }
}

function geminiApiUrl(config: LlmRuntimeConfig, path: string): string {
  const root = new URL(config.baseUrl);
  root.search = '';
  root.hash = '';
  root.pathname = root.pathname.replace(/\/+$/, '');
  if (root.pathname.endsWith('/v1beta')) {
    root.pathname = root.pathname.slice(0, -'/v1beta'.length) || '/';
  }
  return new URL(`/v1beta/${path.replace(/^\/+/, '')}`, root).toString();
}

async function readJsonResponse(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return { raw: text };
  }
}

function providerErrorMessage(payload: unknown, fallback: string): string {
  if (isRecord(payload)) {
    const error = payload.error;
    if (isRecord(error) && typeof error.message === 'string') {
      return error.message;
    }
    if (typeof payload.message === 'string') {
      return payload.message;
    }
  }
  return fallback;
}

async function postGeminiJson(
  config: LlmRuntimeConfig,
  path: string,
  body: Record<string, unknown>,
): Promise<unknown> {
  const response = await fetch(geminiApiUrl(config, path), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': config.apiKey,
    },
    body: JSON.stringify(body),
  });
  const payload = await readJsonResponse(response);
  if (!response.ok) {
    throw new MediaGenerationError(
      providerErrorMessage(payload, `Gemini request failed with ${response.status}`),
      502,
    );
  }
  return payload;
}

async function getGeminiJson(
  config: LlmRuntimeConfig,
  path: string,
): Promise<unknown> {
  const response = await fetch(geminiApiUrl(config, path), {
    headers: { 'x-goog-api-key': config.apiKey },
  });
  const payload = await readJsonResponse(response);
  if (!response.ok) {
    throw new MediaGenerationError(
      providerErrorMessage(payload, `Gemini request failed with ${response.status}`),
      502,
    );
  }
  return payload;
}

function collectStringValues(value: unknown, keyNames: Set<string>, output: string[]): void {
  if (Array.isArray(value)) {
    for (const item of value) collectStringValues(item, keyNames, output);
    return;
  }
  if (!isRecord(value)) return;
  for (const [key, nested] of Object.entries(value)) {
    if (keyNames.has(key) && typeof nested === 'string' && nested.trim()) {
      output.push(nested.trim());
    }
    collectStringValues(nested, keyNames, output);
  }
}

function findGeneratedImage(payload: unknown): { dataBase64: string; mimeType: string } {
  const records: Record<string, unknown>[] = [];
  if (isRecord(payload)) {
    const direct = payload.output_image ?? payload.outputImage;
    if (isRecord(direct)) records.push(direct);
  }
  const dataCandidates: string[] = [];
  collectStringValues(payload, new Set(['data']), dataCandidates);
  for (const record of records) {
    const data = record.data;
    if (typeof data === 'string' && data.trim()) {
      return {
        dataBase64: data.trim(),
        mimeType:
          (typeof record.mime_type === 'string' && record.mime_type.trim()) ||
          (typeof record.mimeType === 'string' && record.mimeType.trim()) ||
          'image/png',
      };
    }
  }
  const dataBase64 = dataCandidates[0];
  if (dataBase64) {
    return { dataBase64, mimeType: 'image/png' };
  }
  throw new MediaGenerationError('Gemini did not return generated image data', 502);
}

function findProviderOperationName(payload: unknown): string | null {
  if (!isRecord(payload)) return null;
  const id = payload.id ?? payload.name;
  return typeof id === 'string' && id.trim() ? id.trim() : null;
}

async function loadReadyImageMedia(params: {
  userId: string;
  channelId: string;
  mediaId: string;
}): Promise<MediaAsset> {
  const asset = await getMediaAssetForUser(params.userId, params.mediaId);
  if (!asset || asset.channelId !== params.channelId) {
    throw new MediaGenerationError('Reference image not found', 404);
  }
  if (asset.kind !== 'image' || asset.status !== 'ready') {
    throw new MediaGenerationError('Reference media must be a ready image', 400);
  }
  return asset;
}

async function assetToBase64ImagePart(asset: MediaAsset): Promise<{
  mimeType: string;
  data: string;
}> {
  const filePath = await resolveMediaAssetPath(asset);
  const bytes = await readFile(filePath);
  return {
    mimeType: asset.mimeType,
    data: bytes.toString('base64'),
  };
}

async function loadImageParts(params: {
  userId: string;
  channelId: string;
  mediaIds: string[];
  maxCount?: number;
}): Promise<Array<{ mediaId: string; mimeType: string; data: string }>> {
  const maxCount = params.maxCount ?? params.mediaIds.length;
  if (params.mediaIds.length > maxCount) {
    throw new MediaGenerationError(`Reference images are limited to ${maxCount}`, 400);
  }
  const parts = [];
  for (const mediaId of params.mediaIds) {
    const asset = await loadReadyImageMedia({
      userId: params.userId,
      channelId: params.channelId,
      mediaId,
    });
    const image = await assetToBase64ImagePart(asset);
    parts.push({ mediaId, ...image });
  }
  return parts;
}

function uniqueIds(ids: Array<string | null | undefined>): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const id of ids) {
    const trimmed = id?.trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    result.push(trimmed);
  }
  return result;
}

export async function generateImageMedia(params: {
  userId: string;
  channelId: string;
  threadId?: string | null;
  prompt: string;
  referenceMediaIds?: string[];
  model?: string | null;
  configId?: string | null;
}): Promise<{ job: MediaGenerationJob; media: MediaAsset }> {
  const prompt = params.prompt.trim();
  if (!prompt) throw new MediaGenerationError('prompt is required', 400);
  const referenceMediaIds = uniqueIds(params.referenceMediaIds ?? []);
  const model = params.model?.trim() || GEMINI_IMAGE_GENERATION_MODEL;

  const references = await loadImageParts({
    userId: params.userId,
    channelId: params.channelId,
    mediaIds: referenceMediaIds,
  });
  let job = await createMediaGenerationJob({
    userId: params.userId,
    channelId: params.channelId,
    threadId: params.threadId,
    kind: 'image',
    status: 'running',
    prompt,
    inputMediaIds: referenceMediaIds,
    provider: 'google_ai_studio',
    model,
  });

  try {
    const config = await resolveGoogleConfig(params.userId, params.configId ?? undefined);
    const payload = await postGeminiJson(config, 'interactions', {
      model,
      input: [
        { type: 'text', text: prompt },
        ...references.map((reference) => ({
          type: 'image',
          mime_type: reference.mimeType,
          data: reference.data,
        })),
      ],
    });
    const generated = findGeneratedImage(payload);
    const providerOperationName = findProviderOperationName(payload);
    const media = await createImageMediaAsset({
      userId: params.userId,
      channelId: params.channelId,
      threadId: params.threadId,
      origin: 'generated_image',
      mimeType: generated.mimeType,
      dataBase64: generated.dataBase64,
      provider: 'google_ai_studio',
      providerOperationName,
      prompt,
    });
    job = await updateMediaGenerationJob(job.id, {
      status: 'succeeded',
      providerOperationName,
      resultMediaId: media.id,
      errorText: null,
    });
    return { job, media };
  } catch (error) {
    await updateMediaGenerationJob(job.id, {
      status: 'failed',
      errorText: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

function validateVideoOptions(params: {
  referenceMediaIds: string[];
  firstFrameMediaId?: string | null;
  lastFrameMediaId?: string | null;
  aspectRatio?: string | null;
  durationSeconds?: number | null;
  resolution?: string | null;
}): void {
  if (params.referenceMediaIds.length > 3) {
    throw new MediaGenerationError('Veo referenceImages supports at most 3 images', 400);
  }
  if (params.referenceMediaIds.length > 0 && (params.firstFrameMediaId || params.lastFrameMediaId)) {
    throw new MediaGenerationError(
      'Use either referenceMediaIds or first/last frame inputs, not both',
      400,
    );
  }
  if (params.lastFrameMediaId && !params.firstFrameMediaId) {
    throw new MediaGenerationError('lastFrameMediaId requires firstFrameMediaId', 400);
  }
  if (params.aspectRatio && !['16:9', '9:16'].includes(params.aspectRatio)) {
    throw new MediaGenerationError('aspectRatio must be 16:9 or 9:16', 400);
  }
  if (
    params.durationSeconds != null &&
    ![4, 6, 8].includes(params.durationSeconds)
  ) {
    throw new MediaGenerationError('durationSeconds must be 4, 6, or 8', 400);
  }
  if (params.referenceMediaIds.length > 0 && params.durationSeconds != null && params.durationSeconds !== 8) {
    throw new MediaGenerationError('durationSeconds must be 8 when using reference images', 400);
  }
  if (params.resolution && !['720p', '1080p', '4k'].includes(params.resolution)) {
    throw new MediaGenerationError('resolution must be 720p, 1080p, or 4k', 400);
  }
  if (params.resolution && ['1080p', '4k'].includes(params.resolution)) {
    const duration = params.durationSeconds ?? 8;
    if (duration !== 8) {
      throw new MediaGenerationError('durationSeconds must be 8 for 1080p or 4k video', 400);
    }
  }
}

export async function startVideoGenerationJob(params: {
  userId: string;
  channelId: string;
  threadId?: string | null;
  prompt: string;
  referenceMediaIds?: string[];
  firstFrameMediaId?: string | null;
  lastFrameMediaId?: string | null;
  aspectRatio?: string | null;
  durationSeconds?: number | null;
  resolution?: string | null;
  model?: string | null;
  configId?: string | null;
}): Promise<MediaGenerationJob> {
  const prompt = params.prompt.trim();
  if (!prompt) throw new MediaGenerationError('prompt is required', 400);
  const referenceMediaIds = uniqueIds(params.referenceMediaIds ?? []);
  const firstFrameMediaId = params.firstFrameMediaId?.trim() || null;
  const lastFrameMediaId = params.lastFrameMediaId?.trim() || null;
  validateVideoOptions({
    referenceMediaIds,
    firstFrameMediaId,
    lastFrameMediaId,
    aspectRatio: params.aspectRatio,
    durationSeconds: params.durationSeconds,
    resolution: params.resolution,
  });

  const inputMediaIds = uniqueIds([
    ...referenceMediaIds,
    firstFrameMediaId,
    lastFrameMediaId,
  ]);
  const model = params.model?.trim() || GEMINI_VIDEO_GENERATION_MODEL;
  let job = await createMediaGenerationJob({
    userId: params.userId,
    channelId: params.channelId,
    threadId: params.threadId,
    kind: 'video',
    status: 'running',
    prompt,
    inputMediaIds,
    provider: 'google_ai_studio',
    model,
  });

  try {
    const [references, firstFrame, lastFrame] = await Promise.all([
      loadImageParts({
        userId: params.userId,
        channelId: params.channelId,
        mediaIds: referenceMediaIds,
        maxCount: 3,
      }),
      firstFrameMediaId
        ? loadImageParts({
            userId: params.userId,
            channelId: params.channelId,
            mediaIds: [firstFrameMediaId],
            maxCount: 1,
          })
        : Promise.resolve([]),
      lastFrameMediaId
        ? loadImageParts({
            userId: params.userId,
            channelId: params.channelId,
            mediaIds: [lastFrameMediaId],
            maxCount: 1,
          })
        : Promise.resolve([]),
    ]);
    const instance: Record<string, unknown> = { prompt };
    if (references.length > 0) {
      instance.referenceImages = references.map((reference) => ({
        image: {
          inlineData: {
            mimeType: reference.mimeType,
            data: reference.data,
          },
        },
        referenceType: 'asset',
      }));
    }
    if (firstFrame[0]) {
      instance.image = {
        inlineData: {
          mimeType: firstFrame[0].mimeType,
          data: firstFrame[0].data,
        },
      };
    }
    if (lastFrame[0]) {
      instance.lastFrame = {
        inlineData: {
          mimeType: lastFrame[0].mimeType,
          data: lastFrame[0].data,
        },
      };
    }

    const parameters: Record<string, unknown> = {};
    if (params.aspectRatio) parameters.aspectRatio = params.aspectRatio;
    if (params.durationSeconds) parameters.durationSeconds = String(params.durationSeconds);
    if (!params.durationSeconds && references.length > 0) parameters.durationSeconds = '8';
    if (params.resolution) parameters.resolution = params.resolution;

    const config = await resolveGoogleConfig(params.userId, params.configId ?? undefined);
    const payload = await postGeminiJson(config, `models/${model}:predictLongRunning`, {
      instances: [instance],
      ...(Object.keys(parameters).length > 0 ? { parameters } : {}),
    });
    const operationName = findProviderOperationName(payload);
    if (!operationName) {
      throw new MediaGenerationError('Veo did not return an operation name', 502);
    }
    job = await updateMediaGenerationJob(job.id, {
      status: 'running',
      providerOperationName: operationName,
      errorText: null,
    });
    return job;
  } catch (error) {
    await updateMediaGenerationJob(job.id, {
      status: 'failed',
      errorText: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

function extractVideoUri(payload: unknown): string | null {
  const values: string[] = [];
  collectStringValues(payload, new Set(['uri']), values);
  return values.find((value) => /^https:\/\//i.test(value)) ?? null;
}

async function downloadGeneratedVideo(
  config: LlmRuntimeConfig,
  uri: string,
): Promise<{ data: Buffer; mimeType: string }> {
  const response = await fetch(uri, {
    headers: { 'x-goog-api-key': config.apiKey },
  });
  if (!response.ok) {
    throw new MediaGenerationError(
      `Generated video download failed with ${response.status}`,
      502,
    );
  }
  const data = Buffer.from(await response.arrayBuffer());
  const contentType = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase();
  return {
    data,
    mimeType: contentType && contentType.startsWith('video/') ? contentType : 'video/mp4',
  };
}

export async function refreshVideoGenerationJobForUser(params: {
  userId: string;
  jobId: string;
  configId?: string | null;
}): Promise<{ job: MediaGenerationJob; media: MediaAsset | null }> {
  let job = await getMediaGenerationJobForUser(params.userId, params.jobId);
  if (!job) throw new MediaGenerationError('Media generation job not found', 404);
  let media: MediaAsset | null = null;
  if (job.resultMediaId) {
    media = await getMediaAssetForUser(params.userId, job.resultMediaId);
  }
  if (job.kind !== 'video' || job.status === 'succeeded' || job.status === 'failed') {
    return { job, media };
  }
  if (!job.providerOperationName) {
    job = await updateMediaGenerationJob(job.id, {
      status: 'failed',
      errorText: 'Veo operation name is missing',
    });
    return { job, media: null };
  }

  const config = await resolveGoogleConfig(params.userId, params.configId ?? undefined);
  const payload = await getGeminiJson(config, job.providerOperationName);
  if (isRecord(payload) && isRecord(payload.error)) {
    const message = providerErrorMessage(payload, 'Veo operation failed');
    job = await updateMediaGenerationJob(job.id, {
      status: 'failed',
      errorText: message,
    });
    return { job, media: null };
  }
  const done = isRecord(payload) && payload.done === true;
  if (!done) {
    return { job, media: null };
  }
  const videoUri = extractVideoUri(payload);
  if (!videoUri) {
    job = await updateMediaGenerationJob(job.id, {
      status: 'failed',
      errorText: 'Veo operation completed without a video URI',
    });
    return { job, media: null };
  }
  const generated = await downloadGeneratedVideo(config, videoUri);
  media = await createVideoMediaAsset({
    userId: job.userId,
    channelId: job.channelId,
    threadId: job.threadId,
    origin: 'generated_video',
    mimeType: generated.mimeType,
    filename: `${job.id}.mp4`,
    data: generated.data,
    provider: job.provider,
    providerOperationName: job.providerOperationName,
    prompt: job.prompt,
  });
  job = await updateMediaGenerationJob(job.id, {
    status: 'succeeded',
    resultMediaId: media.id,
    errorText: null,
  });
  return { job, media };
}
