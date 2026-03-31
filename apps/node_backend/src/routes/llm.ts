import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import { generateWithUserConfig } from '../llm/llm_service.js';
import { LlmProvider, UnifiedChatRequest } from '../llm/types.js';

const router = express.Router();
const SUPPORTED_PROVIDERS = new Set<LlmProvider>(['anthropic', 'google_ai_studio']);

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

    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'messages must be a non-empty array' });
      return;
    }

    const normalizedMessages = messages
      .filter(
        (message) =>
          message &&
          typeof message === 'object' &&
          typeof message.role === 'string' &&
          typeof message.content === 'string'
      )
      .map((message) => ({
        role: message.role,
        content: message.content,
      }));

    if (normalizedMessages.length !== messages.length) {
      res.status(400).json({ error: 'Invalid message format' });
      return;
    }

    const response = await generateWithUserConfig(
      userId,
      {
        model: typeof model === 'string' ? model : undefined,
        messages: normalizedMessages as UnifiedChatRequest['messages'],
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
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'messages must be a non-empty array' });
      return;
    }

    const response = await generateWithUserConfig(
      userId,
      {
        model: typeof model === 'string' ? model : undefined,
        messages: messages as UnifiedChatRequest['messages'],
        temperature: typeof temperature === 'number' ? temperature : undefined,
        maxTokens: typeof maxTokens === 'number' ? maxTokens : undefined,
      },
      preferredProvider ?? undefined
    );

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const chunks = response.text.split(/(\s+)/).filter(Boolean);
    for (const chunk of chunks) {
      res.write(`data: ${JSON.stringify({ type: 'text-delta', delta: chunk })}\n\n`);
    }
    res.write(
      `data: ${JSON.stringify({
        type: 'done',
        provider: response.provider,
        model: response.model,
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
