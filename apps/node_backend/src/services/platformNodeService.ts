import pool from '../db/index.js';

export interface PlatformNode {
  nodeId: string;
  displayName: string;
  pluginId: string;
  createdAt: string;
  updatedAt: string;
}

interface PlatformNodeRow {
  node_id: string;
  display_name: string;
  plugin_id: string;
  created_at: string;
  updated_at: string;
}

function toPlatformNode(row: PlatformNodeRow): PlatformNode {
  return {
    nodeId: row.node_id,
    displayName: row.display_name,
    pluginId: row.plugin_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function normalizedNameSet(nodes: PlatformNode[]): Set<string> {
  return new Set(nodes.map((node) => node.displayName.trim().toLowerCase()));
}

export function nextDefaultNodeName(existingNodes: PlatformNode[]): string {
  const seen = normalizedNameSet(existingNodes);
  for (let i = 1; i <= 9999; i += 1) {
    const candidate = `openclaw ${i}`;
    if (!seen.has(candidate)) return candidate;
  }
  return `openclaw ${Date.now()}`;
}

function buildNodeId(): string {
  return `node_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function pluginIdForNodeId(nodeId: string): string {
  return `plugin_${nodeId}`;
}

export async function listPlatformNodes(userId: string): Promise<PlatformNode[]> {
  const result = await pool.query<PlatformNodeRow>(
    `SELECT node_id, display_name, plugin_id, created_at, updated_at
       FROM platform_nodes
      WHERE user_id = $1
      ORDER BY created_at ASC`,
    [userId],
  );
  return result.rows.map(toPlatformNode);
}

export async function createPlatformNode(
  userId: string,
  input: { displayName?: string | null; pluginId?: string | null } = {},
): Promise<PlatformNode> {
  const existing = await listPlatformNodes(userId);
  const displayNameRaw = input.displayName?.trim();
  const displayName = displayNameRaw && displayNameRaw.length > 0
    ? displayNameRaw
    : nextDefaultNodeName(existing);

  const nodeId = buildNodeId();
  const pluginId = input.pluginId?.trim() || pluginIdForNodeId(nodeId);

  const inserted = await pool.query<PlatformNodeRow>(
    `INSERT INTO platform_nodes (user_id, node_id, display_name, plugin_id)
     VALUES ($1, $2, $3, $4)
     RETURNING node_id, display_name, plugin_id, created_at, updated_at`,
    [userId, nodeId, displayName, pluginId],
  );

  return toPlatformNode(inserted.rows[0]);
}

export async function renamePlatformNode(
  userId: string,
  nodeId: string,
  displayName: string,
): Promise<PlatformNode | null> {
  const trimmed = displayName.trim();
  if (!trimmed) {
    throw new Error('DISPLAY_NAME_REQUIRED');
  }

  const updated = await pool.query<PlatformNodeRow>(
    `UPDATE platform_nodes
        SET display_name = $3,
            updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND node_id = $2
      RETURNING node_id, display_name, plugin_id, created_at, updated_at`,
    [userId, nodeId, trimmed],
  );

  return updated.rows[0] ? toPlatformNode(updated.rows[0]) : null;
}

export async function getPlatformNodeByNodeId(
  userId: string,
  nodeId: string,
): Promise<PlatformNode | null> {
  const result = await pool.query<PlatformNodeRow>(
    `SELECT node_id, display_name, plugin_id, created_at, updated_at
       FROM platform_nodes
      WHERE user_id = $1
        AND node_id = $2
      LIMIT 1`,
    [userId, nodeId],
  );
  return result.rows[0] ? toPlatformNode(result.rows[0]) : null;
}

export async function getPlatformNodeByPluginId(
  userId: string,
  pluginId: string,
): Promise<PlatformNode | null> {
  const result = await pool.query<PlatformNodeRow>(
    `SELECT node_id, display_name, plugin_id, created_at, updated_at
       FROM platform_nodes
      WHERE user_id = $1
        AND plugin_id = $2
      LIMIT 1`,
    [userId, pluginId],
  );
  return result.rows[0] ? toPlatformNode(result.rows[0]) : null;
}

export async function ensureDefaultPlatformNode(userId: string): Promise<PlatformNode> {
  const nodes = await listPlatformNodes(userId);
  if (nodes.length > 0) {
    return nodes[0];
  }
  const defaultPluginId =
    process.env.BRICKS_PLATFORM_DEFAULT_PLUGIN_ID?.trim() || 'plugin_local_main';
  return createPlatformNode(userId, {
    displayName: 'openclaw 1',
    pluginId: defaultPluginId,
  });
}
