import express from 'express';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const {
  ensureDefaultPlatformNodeMock,
  listPlatformNodesMock,
  createPlatformNodeMock,
  renamePlatformNodeMock,
  getPlatformNodeByNodeIdMock,
  getPlatformNodeByPluginIdMock,
  listOpenClawRuntimeAgentsMock,
  issuePlatformAccessTokenMock,
} = vi.hoisted(() => ({
  ensureDefaultPlatformNodeMock: vi.fn(async () => ({
    nodeId: 'node_default',
    displayName: 'openclaw 1',
    pluginId: 'plugin_local_main',
  })),
  listPlatformNodesMock: vi.fn(async () => [
    {
      nodeId: 'node_default',
      displayName: 'openclaw 1',
      pluginId: 'plugin_local_main',
      createdAt: '2026-04-21T00:00:00.000Z',
      updatedAt: '2026-04-21T00:00:00.000Z',
    },
  ]),
  createPlatformNodeMock: vi.fn(async () => ({
    nodeId: 'node_2',
    displayName: 'openclaw 2',
    pluginId: 'plugin_node_2',
    createdAt: '2026-04-21T00:00:00.000Z',
    updatedAt: '2026-04-21T00:00:00.000Z',
  })),
  renamePlatformNodeMock: vi.fn(async () => ({
    nodeId: 'node_2',
    displayName: 'aws node',
    pluginId: 'plugin_node_2',
    createdAt: '2026-04-21T00:00:00.000Z',
    updatedAt: '2026-04-21T00:01:00.000Z',
  })),
  getPlatformNodeByNodeIdMock: vi.fn(async () => ({
    nodeId: 'node_2',
    displayName: 'openclaw 2',
    pluginId: 'plugin_node_2',
    createdAt: '2026-04-21T00:00:00.000Z',
    updatedAt: '2026-04-21T00:00:00.000Z',
  })),
  getPlatformNodeByPluginIdMock: vi.fn(async () => null),
  listOpenClawRuntimeAgentsMock: vi.fn(async () => [
    {
      nodeId: 'node_2',
      sourcePlatform: 'openclaw',
      agentId: 'main',
      displayName: 'Main Agent',
      description: null,
    },
  ]),
  issuePlatformAccessTokenMock: vi.fn(() => 'jwt-node-token'),
}));

vi.mock('../middleware/auth.js', () => ({
  authenticate: (req: express.Request, _res: express.Response, next: express.NextFunction) => {
    (req as express.Request & { userId?: string }).userId = 'user-123';
    next();
  },
}));

vi.mock('../services/configService.js', () => ({
  createApiConfig: vi.fn(),
  getApiConfigs: vi.fn(async () => []),
  getApiConfig: vi.fn(),
  updateApiConfig: vi.fn(),
  deleteApiConfig: vi.fn(),
}));

vi.mock('../services/platformNodeService.js', () => ({
  ensureDefaultPlatformNode: ensureDefaultPlatformNodeMock,
  listPlatformNodes: listPlatformNodesMock,
  createPlatformNode: createPlatformNodeMock,
  renamePlatformNode: renamePlatformNodeMock,
  getPlatformNodeByNodeId: getPlatformNodeByNodeIdMock,
  getPlatformNodeByPluginId: getPlatformNodeByPluginIdMock,
}));

vi.mock('../services/openclawAgentRuntimeService.js', () => ({
  listOpenClawRuntimeAgents: listOpenClawRuntimeAgentsMock,
}));

vi.mock('../middleware/platformAuth.js', () => ({
  issuePlatformAccessToken: issuePlatformAccessTokenMock,
}));

let server: ReturnType<express.Express['listen']> | null = null;
let baseUrl = '';

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  const { default: configRoutes } = await import('./config.js');
  app.use('/api/config', configRoutes);

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

describe('config node routes', () => {
  beforeEach(() => {
    ensureDefaultPlatformNodeMock.mockClear();
    listPlatformNodesMock.mockClear();
    createPlatformNodeMock.mockClear();
    renamePlatformNodeMock.mockClear();
    getPlatformNodeByNodeIdMock.mockClear();
    getPlatformNodeByPluginIdMock.mockClear();
    listOpenClawRuntimeAgentsMock.mockClear();
    issuePlatformAccessTokenMock.mockClear();
  });

  it('lists nodes', async () => {
    const response = await fetch(`${baseUrl}/api/config/nodes`);
    expect(response.status).toBe(200);
    const body = (await response.json()) as { nodes?: Array<{ displayName: string }> };
    expect(body.nodes?.[0]?.displayName).toBe('openclaw 1');
  });

  it('creates nodes', async () => {
    const response = await fetch(`${baseUrl}/api/config/nodes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'aws node' }),
    });
    expect(response.status).toBe(201);
    expect(createPlatformNodeMock).toHaveBeenCalledWith('user-123', {
      displayName: 'aws node',
    });
  });

  it('renames nodes', async () => {
    const response = await fetch(`${baseUrl}/api/config/nodes/node_2`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ displayName: 'aws node' }),
    });
    expect(response.status).toBe(200);
    expect(renamePlatformNodeMock).toHaveBeenCalledWith('user-123', 'node_2', 'aws node');
  });

  it('issues node-scoped platform token', async () => {
    const response = await fetch(`${baseUrl}/api/config/platform-token?nodeId=node_2`);
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      token?: string;
      nodeId?: string;
      nodeName?: string;
      pluginId?: string;
    };
    expect(body.token).toBe('jwt-node-token');
    expect(body.nodeId).toBe('node_2');
    expect(body.nodeName).toBe('openclaw 2');
    expect(body.pluginId).toBe('plugin_node_2');
  });

  it('lists agents for a node', async () => {
    const response = await fetch(
      `${baseUrl}/api/config/nodes/node_2/agents?sourcePlatform=openclaw`,
    );
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      nodeId?: string;
      agents?: Array<{ agentId?: string; displayName?: string }>;
    };
    expect(body.nodeId).toBe('node_2');
    expect(body.agents?.[0]?.agentId).toBe('main');
    expect(body.agents?.[0]?.displayName).toBe('Main Agent');
    expect(listOpenClawRuntimeAgentsMock).toHaveBeenCalledWith('node_2');
  });

  it('does not rate limit config GET reads at app layer', async () => {
    for (let i = 0; i < 100; i += 1) {
      const response = await fetch(`${baseUrl}/api/config?category=llm`);
      expect(response.status).toBe(200);
    }
  });

  it('rate limits config writes per authenticated user after minute budget is exhausted', async () => {
    let limited: globalThis.Response | null = null;
    for (let i = 0; i < 80; i += 1) {
      const response = await fetch(`${baseUrl}/api/config/nodes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ displayName: `node-${i}` }),
      });
      if (response.status === 429) {
        limited = response;
        break;
      }
    }

    expect(limited?.status).toBe(429);
    const body = (await limited!.json()) as { error?: string };
    expect(body.error).toContain('Too many config write requests');
  });

});
