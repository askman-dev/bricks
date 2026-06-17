import pool from '../db/index.js';

export const CHAT_ROUTER_DEFAULT = 'default';
export const CHAT_ROUTER_OPENCLAW = 'openclaw';
export const CHAT_ROUTER_LOCAL = 'local';
export const CHAT_ROUTER_PLUGIN = 'plugin';
export const BUILTIN_DEFAULT_NODE_ID = 'node_builtin_default';
export const BUILTIN_DEFAULT_NODE_NAME = 'Bricks Default';

export type ChatRouter = typeof CHAT_ROUTER_LOCAL | typeof CHAT_ROUTER_PLUGIN;
export type ChatScopeType = 'channel' | 'thread';
export type ChatOutputTonePreset = 'direct' | 'socratic' | 'rhetorical';
export type ChatOutputTone =
  | { type: 'preset'; preset: ChatOutputTonePreset }
  | { type: 'custom'; instruction: string };

interface ChatScopeSettingRow {
  scope_type: ChatScopeType;
  channel_id: string;
  thread_id: string;
  router: ChatRouter;
  node_id: string | null;
  instructions: string | null;
  output_tone_type: string | null;
  output_tone_preset: string | null;
  output_tone_custom: string | null;
  input_grammar_fixer_enabled: boolean | number | null;
  created_at: string;
  updated_at: string;
}

export interface ChatScopeSetting {
  scopeType: ChatScopeType;
  channelId: string;
  threadId: string | null;
  router: ChatRouter;
  nodeId: string | null;
  instructions: string | null;
  outputTone: ChatOutputTone;
  inputGrammarFixerEnabled: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ChatScopeSelector {
  channelId: string;
  threadId?: string | null;
}

export interface ChatScopeSettingInput extends ChatScopeSelector {
  scopeType: ChatScopeType;
  router: ChatRouter;
  nodeId?: string | null;
  instructions?: string | null;
}

export const DEFAULT_CHAT_OUTPUT_TONE_PRESET: ChatOutputTonePreset = 'direct';
export const DEFAULT_CHAT_OUTPUT_TONE: ChatOutputTone = {
  type: 'preset',
  preset: DEFAULT_CHAT_OUTPUT_TONE_PRESET,
};

export function normalizeChatOutputTonePreset(
  value: string | null | undefined,
): ChatOutputTonePreset | null {
  switch (value) {
    case 'direct':
    case 'socratic':
    case 'rhetorical':
      return value;
    default:
      return null;
  }
}

function normalizeOutputTone(row: {
  output_tone_type?: string | null;
  output_tone_preset?: string | null;
  output_tone_custom?: string | null;
}): ChatOutputTone {
  if (row.output_tone_type === 'custom') {
    const instruction = row.output_tone_custom?.trim();
    if (instruction) return { type: 'custom', instruction };
  }

  const preset = normalizeChatOutputTonePreset(row.output_tone_preset);
  return { type: 'preset', preset: preset ?? DEFAULT_CHAT_OUTPUT_TONE_PRESET };
}

function toBoolean(value: boolean | number | null | undefined): boolean {
  return value === true || value === 1;
}

export interface ResolvedChatScopeRouting {
  router: ChatRouter;
  nodeId: string | null;
}

export interface BuiltinDefaultNodeRef {
  nodeId: string;
  nodeName: string;
}

export function builtinDefaultNodeRef(): BuiltinDefaultNodeRef {
  return {
    nodeId: BUILTIN_DEFAULT_NODE_ID,
    nodeName: BUILTIN_DEFAULT_NODE_NAME,
  };
}

export function normalizeChatRouterValue(value: string | null | undefined): ChatRouter | null {
  switch (value) {
    case CHAT_ROUTER_LOCAL:
    case CHAT_ROUTER_DEFAULT:
      return CHAT_ROUTER_LOCAL;
    case CHAT_ROUTER_PLUGIN:
    case CHAT_ROUTER_OPENCLAW:
      return CHAT_ROUTER_PLUGIN;
    default:
      return null;
  }
}

export function normalizeChatThreadId(threadId: string | null | undefined): string {
  const trimmed = threadId?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : 'main';
}

function toStorageThreadId(scopeType: ChatScopeType, threadId?: string | null): string {
  if (scopeType === 'channel') return '';
  return normalizeChatThreadId(threadId);
}

function toDto(row: ChatScopeSettingRow): ChatScopeSetting {
  return {
    scopeType: row.scope_type,
    channelId: row.channel_id,
    threadId: row.scope_type === 'thread' ? row.thread_id : null,
    router: normalizeChatRouterValue(row.router) ?? CHAT_ROUTER_LOCAL,
    nodeId: row.node_id,
    instructions: row.instructions ?? null,
    outputTone:
      row.scope_type === 'channel' ? normalizeOutputTone(row) : DEFAULT_CHAT_OUTPUT_TONE,
    inputGrammarFixerEnabled:
      row.scope_type === 'channel' ? toBoolean(row.input_grammar_fixer_enabled) : false,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function buildChatSessionId(channelId: string, threadId?: string | null): string {
  return `session:${channelId}:${normalizeChatThreadId(threadId)}`;
}

export async function listChatScopeSettings(userId: string): Promise<ChatScopeSetting[]> {
  const result = await pool.query<ChatScopeSettingRow>(
    `SELECT scope_type, channel_id, thread_id, router, node_id, instructions,
            output_tone_type, output_tone_preset, output_tone_custom,
            input_grammar_fixer_enabled, created_at, updated_at
       FROM chat_scope_settings
      WHERE user_id = $1
      ORDER BY channel_id ASC, scope_type ASC, thread_id ASC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function upsertChatScopeSetting(
  userId: string,
  input: ChatScopeSettingInput,
): Promise<ChatScopeSetting> {
  const threadId = toStorageThreadId(input.scopeType, input.threadId);
  const nodeId = input.nodeId?.trim() || null;
  const instructions = input.instructions?.trim() || null;
  const router = normalizeChatRouterValue(input.router) ?? CHAT_ROUTER_LOCAL;
  const result = await pool.query<ChatScopeSettingRow>(
    `INSERT INTO chat_scope_settings (
        user_id,
        scope_type,
        channel_id,
        thread_id,
        router,
        node_id,
        instructions
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (user_id, scope_type, channel_id, thread_id)
      DO UPDATE SET
        router = EXCLUDED.router,
        node_id = EXCLUDED.node_id,
        instructions = EXCLUDED.instructions,
        updated_at = CURRENT_TIMESTAMP
      RETURNING scope_type, channel_id, thread_id, router, node_id, instructions,
                output_tone_type, output_tone_preset, output_tone_custom,
                input_grammar_fixer_enabled, created_at, updated_at`,
    [userId, input.scopeType, input.channelId, threadId, router, nodeId, instructions],
  );

  return toDto(result.rows[0]);
}

export async function setChannelOutputTone(
  userId: string,
  input: { channelId: string; outputTone: ChatOutputTone },
): Promise<ChatScopeSetting> {
  const type = input.outputTone.type;
  const preset = type === 'preset' ? input.outputTone.preset : null;
  const custom = type === 'custom' ? input.outputTone.instruction.trim() : null;
  const result = await pool.query<ChatScopeSettingRow>(
    `INSERT INTO chat_scope_settings (
        user_id,
        scope_type,
        channel_id,
        thread_id,
        router,
        node_id,
        instructions,
        output_tone_type,
        output_tone_preset,
        output_tone_custom
      ) VALUES ($1, 'channel', $2, '', $3, NULL, NULL, $4, $5, $6)
      ON CONFLICT (user_id, scope_type, channel_id, thread_id)
      DO UPDATE SET
        output_tone_type = EXCLUDED.output_tone_type,
        output_tone_preset = EXCLUDED.output_tone_preset,
        output_tone_custom = EXCLUDED.output_tone_custom,
        updated_at = CURRENT_TIMESTAMP
      RETURNING scope_type, channel_id, thread_id, router, node_id, instructions,
                output_tone_type, output_tone_preset, output_tone_custom,
                input_grammar_fixer_enabled, created_at, updated_at`,
    [userId, input.channelId, CHAT_ROUTER_LOCAL, type, preset, custom],
  );

  return toDto(result.rows[0]);
}

export async function setChannelInputGrammarFixer(
  userId: string,
  input: { channelId: string; enabled: boolean },
): Promise<ChatScopeSetting> {
  const result = await pool.query<ChatScopeSettingRow>(
    `INSERT INTO chat_scope_settings (
        user_id,
        scope_type,
        channel_id,
        thread_id,
        router,
        node_id,
        instructions,
        input_grammar_fixer_enabled
      ) VALUES ($1, 'channel', $2, '', $3, NULL, NULL, $4)
      ON CONFLICT (user_id, scope_type, channel_id, thread_id)
      DO UPDATE SET
        input_grammar_fixer_enabled = EXCLUDED.input_grammar_fixer_enabled,
        updated_at = CURRENT_TIMESTAMP
      RETURNING scope_type, channel_id, thread_id, router, node_id, instructions,
                output_tone_type, output_tone_preset, output_tone_custom,
                input_grammar_fixer_enabled, created_at, updated_at`,
    [userId, input.channelId, CHAT_ROUTER_LOCAL, input.enabled],
  );

  return toDto(result.rows[0]);
}

export async function deleteChatScopeSetting(
  userId: string,
  input: Pick<ChatScopeSettingInput, 'scopeType' | 'channelId' | 'threadId'>,
): Promise<{ deleted: boolean }> {
  const threadId = toStorageThreadId(input.scopeType, input.threadId);
  const result = await pool.query(
    `DELETE FROM chat_scope_settings
      WHERE user_id = $1
        AND scope_type = $2
        AND channel_id = $3
        AND thread_id = $4`,
    [userId, input.scopeType, input.channelId, threadId],
  );

  return { deleted: (result.rowCount ?? 0) > 0 };
}

export async function resolveChatRouter(
  userId: string,
  selector: ChatScopeSelector,
): Promise<ChatRouter> {
  const routing = await resolveChatScopeRouting(userId, selector);
  return routing.router;
}

export async function resolveChatScopeRouting(
  userId: string,
  selector: ChatScopeSelector,
): Promise<ResolvedChatScopeRouting> {
  const threadId = normalizeChatThreadId(selector.threadId);
  const result = await pool.query<{ router: ChatRouter; node_id: string | null }>(
    `SELECT router, node_id
       FROM chat_scope_settings
      WHERE user_id = $1
        AND channel_id = $2
        AND (
          (scope_type = 'thread' AND thread_id = $3)
          OR
          (scope_type = 'channel' AND thread_id = '')
        )
      ORDER BY CASE scope_type WHEN 'thread' THEN 0 ELSE 1 END
      LIMIT 1`,
    [userId, selector.channelId, threadId],
  );

  return {
    router: normalizeChatRouterValue(result.rows[0]?.router) ?? CHAT_ROUTER_LOCAL,
    nodeId: result.rows[0]?.node_id ?? null,
  };
}

export interface ResolvedScopeInstructions {
  channelInstructions: string | null;
  threadInstructions: string | null;
  channelOutputTone: ChatOutputTone;
  inputGrammarFixerEnabled: boolean;
}

/**
 * Returns the stored instructions for a channel scope and, when the thread is
 * a sub-section (not 'main'), the thread-level instructions as well.
 *
 * Both values are null when no instructions have been saved.
 */
export async function resolveScopeInstructions(
  userId: string,
  selector: ChatScopeSelector,
): Promise<ResolvedScopeInstructions> {
  const threadId = normalizeChatThreadId(selector.threadId);
  const result = await pool.query<{
    scope_type: ChatScopeType;
    instructions: string | null;
    output_tone_type: string | null;
    output_tone_preset: string | null;
    output_tone_custom: string | null;
    input_grammar_fixer_enabled: boolean | number | null;
  }>(
    `SELECT scope_type, instructions, output_tone_type, output_tone_preset,
            output_tone_custom, input_grammar_fixer_enabled
       FROM chat_scope_settings
      WHERE user_id = $1
        AND channel_id = $2
        AND (
          (scope_type = 'channel' AND thread_id = '')
          OR
          (scope_type = 'thread' AND thread_id = $3)
        )`,
    [userId, selector.channelId, threadId],
  );

  let channelInstructions: string | null = null;
  let threadInstructions: string | null = null;
  let channelOutputTone: ChatOutputTone = DEFAULT_CHAT_OUTPUT_TONE;
  let inputGrammarFixerEnabled = false;

  for (const row of result.rows) {
    const value = row.instructions?.trim() || null;
    if (row.scope_type === 'channel') {
      channelInstructions = value;
      channelOutputTone = normalizeOutputTone(row);
      inputGrammarFixerEnabled = toBoolean(row.input_grammar_fixer_enabled);
    } else if (row.scope_type === 'thread' && threadId !== 'main') {
      threadInstructions = value;
    }
  }

  return { channelInstructions, threadInstructions, channelOutputTone, inputGrammarFixerEnabled };
}
