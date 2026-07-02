import express from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { serviceMock } = vi.hoisted(() => ({
  serviceMock: {
    channelSitePublishStatusDto: vi.fn(),
    getChannelSitePublishStatus: vi.fn(),
  },
}));

vi.mock('../middleware/auth.js', () => ({
  authenticate: (req: express.Request, _res: express.Response, next: express.NextFunction) => {
    (req as express.Request & { userId?: string }).userId = 'user-123';
    next();
  },
}));

vi.mock('../services/channelSiteService.js', () => ({
  ChannelSiteError: class ChannelSiteError extends Error {
    constructor(message: string, public readonly statusCode = 400) {
      super(message);
    }
  },
  channelSitePublishStatusDto: serviceMock.channelSitePublishStatusDto,
  getChannelSitePublishStatus: serviceMock.getChannelSitePublishStatus,
}));

describe('channelSiteApi route', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  async function createApp() {
    const app = express();
    app.use(express.json());
    const { default: route } = await import('./channelSiteApi.js');
    app.use('/api/sites', route);
    return app;
  }

  it('returns publish status for the authenticated user and channel', async () => {
    const site = {
      id: 'site-1',
      userId: 'user-123',
      channelId: 'default',
      publicSlug: 's-abc123',
      latestBuildStatus: 'succeeded',
      latestBuildAt: '2026-07-02T03:00:00.000Z',
      latestPublishCommitSha: 'def456',
      publishedCommitSha: 'def456',
      createdAt: '2026-07-02T02:00:00.000Z',
      updatedAt: '2026-07-02T03:00:00.000Z',
    };
    const status = {
      state: 'published',
      currentCommitSha: 'def456',
      publishedCommitSha: 'def456',
      latestPublishCommitSha: 'def456',
      hasUnpublishedChanges: false,
    };
    serviceMock.getChannelSitePublishStatus.mockResolvedValue({ site, status });
    serviceMock.channelSitePublishStatusDto.mockReturnValue({
      site: { publicUrl: 'https://example.test/sites/s-abc123' },
      publish: status,
    });

    const app = await createApp();
    const server = app.listen(0, '127.0.0.1');
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') {
      throw new Error('Failed to start test server');
    }
    const response = await fetch(
      `http://127.0.0.1:${address.port}/api/sites/default/publish-status`,
    );
    server.close();

    expect(response.status).toBe(200);
    expect(serviceMock.getChannelSitePublishStatus).toHaveBeenCalledWith({
      userId: 'user-123',
      channelId: 'default',
    });
    const body = await response.json() as { publish: { state: string } };
    expect(body.publish.state).toBe('published');
  });
});
