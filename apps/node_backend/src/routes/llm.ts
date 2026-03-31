import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import { generateWithUserConfig, streamWithUserConfig } from '../llm/llm_service.js';
import { LlmProvider, UnifiedChatRequest } from '../llm/types.js';

const router = express.Router();
const SUPPORTED_PROVIDERS = new Set<LlmProvider>(['anthropic', 'google_ai_studio']);
const VALID_ROLES = new Set(['system', 'user', 'assistant']);

function validateMessages(
  messages: unknown
): { valid: true; normalized: UnifiedChatRequest['messages'] } | { valid: false; error: string } {
  if (!Array.isArray(messages) || messages.length === 0) {
    return { valid: false, error: 'messages must be a non-empty array' };
  }

  const normalized: UnifiedChatRequest['messages'] = [];
  for (const msg of messages) {
    if (!msg || typeof msg !== 'object' || typeof msg.role !== 'string' || typeof msg.content !== 'string') {
      return { valid: false, error: 'Each message must have a string role and content' };
    }
    if (!VALID_ROLES.has(msg.role)) {
      return { valid: false, error: `Unsupported message role: '${msg.role}'. Must be one of: system, user, assistant` };
    }
    normalized.push({ role: msg.role as 'system' | 'user' | 'assistant', content: msg.content });
  }
  return { valid: true, normalized };
}

router.use(authenticate);

router.post('/chat', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { provider, model, messages, temperature, maxTokens } = req.body ?? {};
    const preferredProvider = parseProvider(provider);
    if (provider !== undefined && !preferredProvider) {
      res.status(400).json({ error: 'Invalid provider' });
      return;
    }

    const result = validateMessages(messages);
    if (!result.valid) {
      res.status(400).json({ error: result.error });
      return;
    }

    const response = await generateWithUserConfig(
      userId,
      {
        model: typeof model === 'string' ? model : undefined,
        messages: result.normalized,
        temperature: typeof temperature === 'number' ? temperature : undefined,
        maxTokens: typeof maxTokens === 'number' ? maxTokens : undefined,
      },
      preferredProvider ?? undefined
    );

    res.json({
      provider: response.provider,
      model: response.model,
      output: [
        {
          type: 'text',
          text: response.text,
        },
      ],
      finishReason: 'stop',
    });
  } catch (error) {
    console.error('Unified LLM chat error:', error);
    res.status(500).json({ error: 'Failed to generate completion' });
  }
});

router.post('/chat/stream', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { provider, model, messages, temperature, maxTokens } = req.body ?? {};
    const preferredProvider = parseProvider(provider);
    if (provider !== undefined && !preferredProvider) {
      res.status(400).json({ error: 'Invalid provider' });
      return;
    }

    const result = validateMessages(messages);
    if (!result.valid) {
      res.status(400).json({ error: result.error });
      return;
    }

    const { textStream, provider: resolvedProvider, modelId } = await streamWithUserConfig(
      userId,
      {
        model: typeof model === 'string' ? model : undefined,
        messages: result.normalized,
        temperature: typeof temperature === 'number' ? temperature : undefined,
        maxTokens: typeof maxTokens === 'number' ? maxTokens : undefined,
      },
      preferredProvider ?? undefined
    );

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    for await (const chunk of textStream) {
      res.write(`data: ${JSON.stringify({ type: 'text-delta', delta: chunk })}\n\n`);
    }
    res.write(
      `data: ${JSON.stringify({
        type: 'done',
        provider: resolvedProvider,
        model: modelId,
      })}\n\n`
    );
    res.end();
  } catch (error) {
    console.error('Unified LLM stream error:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to stream completion' });
      return;
    }
    res.write(`data: ${JSON.stringify({ type: 'error', message: 'stream failed' })}\n\n`);
    res.end();
  }
});

function parseProvider(value: unknown): LlmProvider | null {
  if (typeof value !== 'string') return null;
  if (SUPPORTED_PROVIDERS.has(value as LlmProvider)) {
    return value as LlmProvider;
  }
  return null;
}

export default router;
