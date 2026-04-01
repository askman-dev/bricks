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

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  if (typeof error === 'string' && error.trim()) {
    return error.trim();
  }
  if (error && typeof error === 'object') {
    const maybeMessage = (error as { message?: unknown }).message;
    if (typeof maybeMessage === 'string' && maybeMessage.trim()) {
      return maybeMessage.trim();
    }
  }
  return 'Unknown error';
}

function classifyLlmError(error: unknown): { status: number; message: string } {
  const message = getErrorMessage(error);
  const lower = message.toLowerCase();

  if (
    lower.includes('no llm configuration') ||
    lower.includes('invalid provider') ||
    lower.includes('invalid endpoint') ||
    lower.includes('invalid provider endpoint') ||
    lower.includes('invalid provider api_key') ||
    lower.includes('decryption failed') ||
    lower.includes('endpoint must use https') ||
    lower.includes("endpoint host '")
  ) {
    return { status: 400, message };
  }

  if (lower.includes('api key') || lower.includes('unauthorized') || lower.includes('forbidden')) {
    return { status: 401, message: 'Provider authentication failed. Please verify API credentials.' };
  }

  if (lower.includes('rate limit') || lower.includes('quota')) {
    return { status: 429, message: 'Provider rate limit exceeded. Please retry later.' };
  }

  return { status: 500, message: 'Failed to generate completion' };
}

router.post('/chat', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { provider, model, configId, messages, temperature, maxTokens } =
      req.body ?? {};
    const preferredProvider = parseProvider(provider);
    if (provider !== undefined && !preferredProvider) {
      res.status(400).json({ error: 'Invalid provider' });
      return;
    }

    const result = validateMessages(messages);
    if (result.valid !== true) {
      res.status(400).json({ error: result.error });
      return;
    }

    const response = await generateWithUserConfig(
      userId,
      {
        model: typeof model === 'string' ? model : undefined,
        configId: typeof configId === 'string' ? configId : undefined,
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
    const { status, message } = classifyLlmError(error);
    res.status(status).json({ error: message });
  }
});

router.post('/chat/stream', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { provider, model, configId, messages, temperature, maxTokens } =
      req.body ?? {};
    const preferredProvider = parseProvider(provider);
    if (provider !== undefined && !preferredProvider) {
      res.status(400).json({ error: 'Invalid provider' });
      return;
    }

    const result = validateMessages(messages);
    if (result.valid !== true) {
      res.status(400).json({ error: result.error });
      return;
    }

    const { textStream, provider: resolvedProvider, modelId } = await streamWithUserConfig(
      userId,
      {
        model: typeof model === 'string' ? model : undefined,
        configId: typeof configId === 'string' ? configId : undefined,
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
      const { status, message } = classifyLlmError(error);
      res.status(status).json({ error: message });
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
