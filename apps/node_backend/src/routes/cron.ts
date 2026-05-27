/**
 * Cron endpoint: process due scheduled actions.
 *
 * Called by Vercel Cron (or any HTTP client) once per minute.
 * Protected by a shared `CRON_SECRET` bearer token — does NOT use user JWT.
 *
 * For each due action the handler:
 *   1. Claims a run record (idempotent via UNIQUE constraint).
 *   2. Advances `next_run_at` so the action is not re-claimed in the same tick.
 *   3. Inserts a user message with `source: scheduled_action`.
 *   4. Runs the agent loop synchronously (no streaming flush).
 *   5. Writes the final assistant message.
 *   6. Marks the run completed or failed.
 */

import express, { Request, Response } from 'express';
import { randomUUID, timingSafeEqual } from 'crypto';
import {
  acceptTask,
  upsertMessages,
  listSessionMessagesForModel,
  type AcceptTaskInput,
} from '../services/chatAsyncTransportService.js';
import {
  buildChatSessionId,
  normalizeChatThreadId,
  resolveScopeInstructions,
} from '../services/chatRouterService.js';
import { streamWithAgentToolsAndUserConfig } from '../llm/llm_service.js';
import { buildAgentTools } from '../services/localAgentLoopService.js';
import {
  queryDueActions,
  claimScheduledActionRun,
  advanceNextRunAt,
  markRunStarted,
  markRunCompleted,
  markRunFailed,
} from '../services/scheduledActionService.js';

const router = express.Router();

const MAX_ASSISTANT_CHARS = 120 * 1024;
const DEFAULT_MAX_STEPS = 10;
const DEFAULT_MAX_TOOL_CALLS = 50;
const DEFAULT_TIMEOUT_MS = 60_000;

function verifyCronAuth(req: Request, res: Response): boolean {
  const cronSecret = process.env.CRON_SECRET;
  if (!cronSecret) {
    // If no secret is configured, block all requests to avoid open execution.
    res.status(403).json({ error: 'CRON_SECRET is not configured' });
    return false;
  }
  const authHeader = req.headers['authorization'];
  const expectedHeader = 'Bearer ' + cronSecret;
  if (
    !authHeader ||
    authHeader.length !== expectedHeader.length ||
    !timingSafeEqual(Buffer.from(authHeader), Buffer.from(expectedHeader))
  ) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}

/**
 * GET /api/cron/scheduled-actions
 *
 * Processes up to 5 due scheduled actions per invocation.
 * Returns a JSON summary of each action processed.
 */
router.get('/scheduled-actions', async (req: Request, res: Response) => {
  if (!verifyCronAuth(req, res)) return;

  const fireTime = new Date();
  const dueActions = await queryDueActions();

  const results: Array<{
    actionId: string;
    runId: string | null;
    status: 'claimed' | 'skipped' | 'completed' | 'failed';
    error?: string;
  }> = [];

  for (const action of dueActions) {
    // Attempt to claim a run for this fire time.
    const run = await claimScheduledActionRun(action, fireTime);
    if (!run) {
      // Another cron invocation already claimed this slot — skip.
      results.push({ actionId: action.id, runId: null, status: 'skipped' });
      continue;
    }

    // Advance next_run_at immediately so the next cron tick won't re-claim.
    await advanceNextRunAt(action.id, new Date(action.nextRunAt), action.intervalSeconds);
    await markRunStarted(run.id);

    let chatTaskId: string | null = null;
    let chatMessageId: string | null = null;

    try {
      const normalizedThreadId = normalizeChatThreadId(action.threadId);
      const sessionId = buildChatSessionId(action.channelId, normalizedThreadId);
      const taskId = randomUUID();
      const userMessageId = randomUUID();
      const assistantMessageId = randomUUID();

      const acceptInput: AcceptTaskInput = {
        taskId,
        idempotencyKey: run.id,
        channelId: action.channelId,
        sessionId,
        threadId: normalizedThreadId,
        resolvedBotId: null,
        resolvedSkillId: null,
      };
      const acceptedTask = await acceptTask(action.userId, acceptInput);
      chatTaskId = acceptedTask.taskId;
      chatMessageId = assistantMessageId;

      // Insert user message.
      await upsertMessages(action.userId, [
        {
          messageId: userMessageId,
          taskId: acceptedTask.taskId,
          channelId: action.channelId,
          sessionId: acceptedTask.sessionId,
          threadId: normalizedThreadId,
          role: 'user',
          content: action.prompt,
          taskState: 'accepted',
          checkpointCursor: null,
          metadata: {
            source: 'scheduled_action',
            scheduledActionId: action.id,
            scheduledRunId: run.id,
          },
          createdAt: null,
        },
      ]);

      // Insert dispatch placeholder for the assistant message.
      await upsertMessages(action.userId, [
        {
          messageId: assistantMessageId,
          taskId: acceptedTask.taskId,
          channelId: action.channelId,
          sessionId: acceptedTask.sessionId,
          threadId: normalizedThreadId,
          role: 'assistant',
          content: '',
          taskState: 'dispatched',
          checkpointCursor: null,
          metadata: {
            source: 'backend.cron.scheduled_action',
            dispatchPlaceholder: true,
            scheduledActionId: action.id,
            scheduledRunId: run.id,
          },
          createdAt: null,
        },
      ]);

      // Resolve scope instructions (channel + thread).
      const scopeInstructions = await resolveScopeInstructions(action.userId, {
        channelId: action.channelId,
        threadId: normalizedThreadId,
      });

      // Build system prompt with session context.
      const ctxLines = [`Channel ID: ${action.channelId}`];
      if (normalizedThreadId && normalizedThreadId !== 'main') {
        ctxLines.push(`Thread ID: ${normalizedThreadId}`);
      }
      const systemParts: string[] = [`Session context:\n${ctxLines.map((l) => `- ${l}`).join('\n')}`];
      if (scopeInstructions.channelInstructions?.trim()) {
        systemParts.push(`Channel context:\n${scopeInstructions.channelInstructions.trim()}`);
      }
      if (scopeInstructions.threadInstructions?.trim()) {
        systemParts.push(`Section context:\n${scopeInstructions.threadInstructions.trim()}`);
      }
      const composedSystemPrompt = systemParts.join('\n\n');

      // Load session history.
      const modelMessages = await listSessionMessagesForModel(action.userId, acceptedTask.sessionId, {
        limit: 40,
        maxChars: 10000,
      });
      const messagesWithSystem = [
        { role: 'system' as const, content: composedSystemPrompt },
        ...modelMessages,
      ];

      // Run the agent loop.
      const agentTools = buildAgentTools(action.userId);
      const streamResult = await streamWithAgentToolsAndUserConfig(
        action.userId,
        {
          messages: messagesWithSystem,
        },
        agentTools,
        {
          maxSteps: DEFAULT_MAX_STEPS,
          maxToolCalls: DEFAULT_MAX_TOOL_CALLS,
          timeoutMs: DEFAULT_TIMEOUT_MS,
        },
      );

      // Collect full text (no intermediate flushes needed in cron context).
      let assistantContent = '';
      for await (const chunk of streamResult.textStream) {
        if (typeof chunk === 'string') {
          assistantContent += chunk;
          if (assistantContent.length >= MAX_ASSISTANT_CHARS) break;
        }
      }

      // Write final assistant message.
      const finalContent = assistantContent.trim() || '(no response)';
      await upsertMessages(action.userId, [
        {
          messageId: assistantMessageId,
          taskId: acceptedTask.taskId,
          channelId: action.channelId,
          sessionId: acceptedTask.sessionId,
          threadId: normalizedThreadId,
          role: 'assistant',
          content: finalContent,
          taskState: 'completed',
          checkpointCursor: null,
          metadata: {
            source: 'backend.cron.scheduled_action',
            scheduledActionId: action.id,
            scheduledRunId: run.id,
          },
          createdAt: null,
        },
      ]);

      await markRunCompleted(run.id, chatTaskId, chatMessageId);
      results.push({ actionId: action.id, runId: run.id, status: 'completed' });
    } catch (error) {
      const errorText = error instanceof Error ? error.message : String(error);
      console.error('Cron scheduled action execution error:', {
        actionId: action.id,
        runId: run.id,
        error: errorText,
      });

      // Write a failed assistant message so the run is visible in the chat history.
      if (chatTaskId && chatMessageId) {
        try {
          await upsertMessages(action.userId, [
            {
              messageId: chatMessageId,
              taskId: chatTaskId,
              channelId: action.channelId,
              sessionId: buildChatSessionId(
                action.channelId,
                normalizeChatThreadId(action.threadId),
              ),
              threadId: normalizeChatThreadId(action.threadId),
              role: 'assistant',
              content: `Error: ${errorText}`,
              taskState: 'failed',
              checkpointCursor: null,
              metadata: {
                source: 'backend.cron.scheduled_action',
                scheduledActionId: action.id,
                scheduledRunId: run.id,
                error: errorText,
              },
              createdAt: null,
            },
          ]);
        } catch {
          // Ignore secondary write error.
        }
      }

      await markRunFailed(run.id, errorText);
      results.push({ actionId: action.id, runId: run.id, status: 'failed', error: errorText });
    }
  }

  res.json({ processed: results.length, results });
});

export default router;
