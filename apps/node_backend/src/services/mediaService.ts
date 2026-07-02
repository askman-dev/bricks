import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';
import pool from '../db/index.js';
import {
  ensureSafeChannelRelativePath,
  resolveChannelPath,
  writeChannelFile,
} from './channelFileService.js';

export type MediaKind = 'image' | 'video' | 'file';
export type MediaOrigin = 'user_upload' | 'generated_image' | 'generated_video';
export type MediaStatus = 'ready' | 'failed';

export interface MediaAsset {
  id: string;
  userId: string;
  channelId: string;
  threadId: string | null;
  kind: MediaKind;
  origin: MediaOrigin;
  status: MediaStatus;
  mimeType: string;
  filename: string;
  channelRelativePath: string;
  thumbnailChannelRelativePath: string | null;
  sizeBytes: number;
  width: number | null;
  height: number | null;
  durationMs: number | null;
  sourceMessageId: string | null;
  provider: string | null;
  providerOperationName: string | null;
  prompt: string | null;
  errorText: string | null;
  createdAt: string;
  updatedAt: string;
}

interface MediaAssetRow {
  id: string;
  user_id: string;
  channel_id: string;
  thread_id: string | null;
  kind: MediaKind;
  origin: MediaOrigin;
  status: MediaStatus;
  mime_type: string;
  filename: string;
  channel_relative_path: string;
  thumbnail_channel_relative_path: string | null;
  size_bytes: number;
  width: number | null;
  height: number | null;
  duration_ms: number | null;
  source_message_id: string | null;
  provider: string | null;
  provider_operation_name: string | null;
  prompt: string | null;
  error_text: string | null;
  created_at: string;
  updated_at: string;
}

const IMAGE_MIME_TO_EXTENSION = new Map<string, string>([
  ['image/png', 'png'],
  ['image/jpeg', 'jpg'],
  ['image/webp', 'webp'],
  ['image/gif', 'gif'],
]);

const VIDEO_MIME_TO_EXTENSION = new Map<string, string>([
  ['video/mp4', 'mp4'],
]);

const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const MAX_VIDEO_BYTES = 512 * 1024 * 1024;

function toMediaAsset(row: MediaAssetRow): MediaAsset {
  return {
    id: row.id,
    userId: row.user_id,
    channelId: row.channel_id,
    threadId: row.thread_id,
    kind: row.kind,
    origin: row.origin,
    status: row.status,
    mimeType: row.mime_type,
    filename: row.filename,
    channelRelativePath: row.channel_relative_path,
    thumbnailChannelRelativePath: row.thumbnail_channel_relative_path,
    sizeBytes: Number(row.size_bytes),
    width: row.width == null ? null : Number(row.width),
    height: row.height == null ? null : Number(row.height),
    durationMs: row.duration_ms == null ? null : Number(row.duration_ms),
    sourceMessageId: row.source_message_id,
    provider: row.provider,
    providerOperationName: row.provider_operation_name,
    prompt: row.prompt,
    errorText: row.error_text,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function assertSupportedImage(mimeType: string, data: Buffer): string {
  const normalizedMime = mimeType.trim().toLowerCase();
  const extension = IMAGE_MIME_TO_EXTENSION.get(normalizedMime);
  if (!extension) {
    throw new Error('Unsupported image MIME type');
  }
  if (data.length === 0) {
    throw new Error('Image data is empty');
  }
  if (data.length > MAX_IMAGE_BYTES) {
    throw new Error('Image exceeds the 20MB limit');
  }
  return extension;
}

export function assertSupportedVideo(mimeType: string, data: Buffer): string {
  const normalizedMime = mimeType.trim().toLowerCase();
  const extension = VIDEO_MIME_TO_EXTENSION.get(normalizedMime);
  if (!extension) {
    throw new Error('Unsupported video MIME type');
  }
  if (data.length === 0) {
    throw new Error('Video data is empty');
  }
  if (data.length > MAX_VIDEO_BYTES) {
    throw new Error('Video exceeds the 512MB limit');
  }
  return extension;
}

function sanitizeFilename(filename: string | undefined, fallback: string): string {
  const trimmed = filename?.trim() ?? '';
  const basename = path.basename(trimmed).replace(/[^A-Za-z0-9._-]+/g, '-');
  return basename && basename !== '.' && basename !== '..' ? basename.slice(0, 120) : fallback;
}

function decodeBase64Data(value: string): Buffer {
  const commaIndex = value.indexOf(',');
  const raw = commaIndex >= 0 ? value.slice(commaIndex + 1) : value;
  return Buffer.from(raw, 'base64');
}

export async function createImageMediaAsset(params: {
  userId: string;
  channelId: string;
  threadId?: string | null;
  origin: Extract<MediaOrigin, 'user_upload' | 'generated_image'>;
  mimeType: string;
  filename?: string;
  dataBase64: string;
  sourceMessageId?: string | null;
  provider?: string | null;
  providerOperationName?: string | null;
  prompt?: string | null;
}): Promise<MediaAsset> {
  const data = decodeBase64Data(params.dataBase64);
  const extension = assertSupportedImage(params.mimeType, data);
  const id = crypto.randomUUID();
  const filename = sanitizeFilename(params.filename, `${id}.${extension}`);
  const relativeDir =
    params.origin === 'user_upload'
      ? 'media/uploads'
      : 'media/generated/images';
  const relativePath = `${relativeDir}/${id}.${extension}`;
  await writeChannelFile({
    userId: params.userId,
    channelId: params.channelId,
    relativePath,
    data,
  });

  const result = await pool.query<MediaAssetRow>(
    `INSERT INTO media_assets (
        id,
        user_id,
        channel_id,
        thread_id,
        kind,
        origin,
        status,
        mime_type,
        filename,
        channel_relative_path,
        size_bytes,
        source_message_id,
        provider,
        provider_operation_name,
        prompt
      ) VALUES ($1,$2,$3,$4,'image',$5,'ready',$6,$7,$8,$9,$10,$11,$12,$13)
      RETURNING *`,
    [
      id,
      params.userId,
      params.channelId,
      params.threadId ?? null,
      params.origin,
      params.mimeType.trim().toLowerCase(),
      filename,
      relativePath,
      data.length,
      params.sourceMessageId ?? null,
      params.provider ?? null,
      params.providerOperationName ?? null,
      params.prompt ?? null,
    ],
  );
  return toMediaAsset(result.rows[0]);
}

export async function createVideoMediaAsset(params: {
  userId: string;
  channelId: string;
  threadId?: string | null;
  origin: Extract<MediaOrigin, 'generated_video'>;
  mimeType: string;
  filename?: string;
  data: Buffer;
  sourceMessageId?: string | null;
  provider?: string | null;
  providerOperationName?: string | null;
  prompt?: string | null;
  durationMs?: number | null;
}): Promise<MediaAsset> {
  const extension = assertSupportedVideo(params.mimeType, params.data);
  const id = crypto.randomUUID();
  const filename = sanitizeFilename(params.filename, `${id}.${extension}`);
  const relativePath = `media/generated/videos/${id}.${extension}`;
  await writeChannelFile({
    userId: params.userId,
    channelId: params.channelId,
    relativePath,
    data: params.data,
  });

  const result = await pool.query<MediaAssetRow>(
    `INSERT INTO media_assets (
        id,
        user_id,
        channel_id,
        thread_id,
        kind,
        origin,
        status,
        mime_type,
        filename,
        channel_relative_path,
        size_bytes,
        duration_ms,
        source_message_id,
        provider,
        provider_operation_name,
        prompt
      ) VALUES ($1,$2,$3,$4,'video',$5,'ready',$6,$7,$8,$9,$10,$11,$12,$13,$14)
      RETURNING *`,
    [
      id,
      params.userId,
      params.channelId,
      params.threadId ?? null,
      params.origin,
      params.mimeType.trim().toLowerCase(),
      filename,
      relativePath,
      params.data.length,
      params.durationMs ?? null,
      params.sourceMessageId ?? null,
      params.provider ?? null,
      params.providerOperationName ?? null,
      params.prompt ?? null,
    ],
  );
  return toMediaAsset(result.rows[0]);
}

export async function getMediaAssetForUser(
  userId: string,
  mediaId: string,
): Promise<MediaAsset | null> {
  const result = await pool.query<MediaAssetRow>(
    `SELECT * FROM media_assets WHERE user_id = $1 AND id = $2 LIMIT 1`,
    [userId, mediaId],
  );
  return result.rows[0] ? toMediaAsset(result.rows[0]) : null;
}

export async function listMediaAssetsForUser(
  userId: string,
  mediaIds: string[],
): Promise<MediaAsset[]> {
  if (mediaIds.length === 0) return [];
  const placeholders = mediaIds.map((_, index) => `$${index + 2}`).join(',');
  const result = await pool.query<MediaAssetRow>(
    `SELECT * FROM media_assets WHERE user_id = $1 AND id IN (${placeholders})`,
    [userId, ...mediaIds],
  );
  return result.rows.map(toMediaAsset);
}

export async function resolveMediaAssetPath(asset: MediaAsset): Promise<string> {
  const safeRelativePath = ensureSafeChannelRelativePath(asset.channelRelativePath);
  const absolutePath = resolveChannelPath(asset.userId, asset.channelId, safeRelativePath);
  const stat = await fs.stat(absolutePath);
  if (!stat.isFile()) {
    throw new Error('Media asset path is not a file');
  }
  return absolutePath;
}

export function mediaAssetToDto(asset: MediaAsset) {
  return {
    id: asset.id,
    kind: asset.kind,
    origin: asset.origin,
    status: asset.status,
    mimeType: asset.mimeType,
    filename: asset.filename,
    sizeBytes: asset.sizeBytes,
    width: asset.width,
    height: asset.height,
    durationMs: asset.durationMs,
    channelId: asset.channelId,
    threadId: asset.threadId,
    channelRelativePath: asset.channelRelativePath,
    previewUrl: `/api/media/${asset.id}/preview`,
    contentUrl: `/api/media/${asset.id}/content`,
    downloadUrl: `/api/media/${asset.id}/download`,
    errorText: asset.errorText,
    createdAt: asset.createdAt,
    updatedAt: asset.updatedAt,
  };
}
