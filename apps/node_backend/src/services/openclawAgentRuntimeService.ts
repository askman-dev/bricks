import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export interface RuntimePlatformAgent {
  nodeId: string;
  sourcePlatform: 'openclaw';
  agentId: string;
  displayName: string;
  description: string | null;
}

function readString(record: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
}

function candidateItems(raw: unknown): unknown[] {
  if (Array.isArray(raw)) return raw;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return [];
  const record = raw as Record<string, unknown>;
  for (const key of ['agents', 'items', 'data', 'results']) {
    const value = record[key];
    if (Array.isArray(value)) return value;
  }
  return [];
}

export function normalizeOpenClawRuntimeAgents(
  nodeId: string,
  raw: unknown,
): RuntimePlatformAgent[] {
  const seen = new Set<string>();
  const agents: RuntimePlatformAgent[] = [];

  for (const item of candidateItems(raw)) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      continue;
    }

    const record = item as Record<string, unknown>;
    const agentId =
      readString(record, ['id', 'agentId', 'name'])
      ?? readString(record, ['agent'])
      ?? null;
    if (!agentId || seen.has(agentId)) {
      continue;
    }

    const displayName =
      readString(record, ['displayName', 'name', 'title'])
      ?? agentId;
    const description =
      readString(record, ['description', 'summary', 'prompt'])
      ?? null;

    seen.add(agentId);
    agents.push({
      nodeId,
      sourcePlatform: 'openclaw',
      agentId,
      displayName,
      description,
    });
  }

  return agents;
}

export async function listOpenClawRuntimeAgents(
  nodeId: string,
): Promise<RuntimePlatformAgent[]> {
  const { stdout } = await execFileAsync('openclaw', ['agents', 'list', '--json']);
  const trimmed = stdout.trim();
  if (!trimmed) {
    return [];
  }
  return normalizeOpenClawRuntimeAgents(nodeId, JSON.parse(trimmed));
}
