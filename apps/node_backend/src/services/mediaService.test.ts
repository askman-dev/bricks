import { describe, expect, it, vi } from 'vitest';

const { poolMock } = vi.hoisted(() => ({
  poolMock: {
    query: vi.fn(),
  },
}));

vi.mock('../db/index.js', () => ({
  default: poolMock,
}));

describe('mediaService validation', () => {
  it('accepts supported image MIME types under the size limit', async () => {
    const { assertSupportedImage } = await import('./mediaService.js');
    expect(assertSupportedImage('image/png', Buffer.from('data'))).toBe('png');
    expect(assertSupportedImage('image/jpeg', Buffer.from('data'))).toBe('jpg');
    expect(assertSupportedImage('image/webp', Buffer.from('data'))).toBe('webp');
  });

  it('rejects unsupported or empty image uploads', async () => {
    const { assertSupportedImage } = await import('./mediaService.js');
    expect(() => assertSupportedImage('text/plain', Buffer.from('data'))).toThrow(
      /Unsupported image MIME type/,
    );
    expect(() => assertSupportedImage('image/png', Buffer.alloc(0))).toThrow(
      /Image data is empty/,
    );
  });

  it('accepts mp4 generated videos and rejects unsupported or empty video data', async () => {
    const { assertSupportedVideo } = await import('./mediaService.js');
    expect(assertSupportedVideo('video/mp4', Buffer.from('data'))).toBe('mp4');
    expect(() => assertSupportedVideo('video/quicktime', Buffer.from('data'))).toThrow(
      /Unsupported video MIME type/,
    );
    expect(() => assertSupportedVideo('video/mp4', Buffer.alloc(0))).toThrow(
      /Video data is empty/,
    );
  });
});
