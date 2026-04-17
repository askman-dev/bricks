import { describe, expect, it } from 'vitest';
import {
  assistantClientTokenForEvent,
  extractIncomingText,
  shouldProcessEvent,
} from '../src/pluginRunner.js';

describe('extractIncomingText', () => {
  it('returns top-level text first', () => {
    expect(extractIncomingText({ text: ' hello ' })).toBe('hello');
  });

  it('falls back to content when text is missing', () => {
    expect(extractIncomingText({ content: ' world ' })).toBe('world');
  });

  it('returns placeholder for empty payload', () => {
    expect(extractIncomingText()).toBe('[empty message]');
  });
});

describe('shouldProcessEvent', () => {
  it('skips assistant/system events', () => {
    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_1',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_1', displayName: 'assistant' } },
        },
      ),
    ).toBe(false);

    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_2',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_2', displayName: 'assistant' } },
        },
      ),
    ).toBe(false);

    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_2b',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_2', displayName: 'system' } },
        },
      ),
    ).toBe(false);
  });

  it('keeps user-created events even when sender userId equals token userId', () => {
    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_3',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_1', displayName: 'user' } },
        },
      ),
    ).toBe(true);
  });
});

describe('assistantClientTokenForEvent', () => {
  it('prefers pending assistant message id from payload metadata', () => {
    expect(
      assistantClientTokenForEvent({
        eventId: 'evt_1',
        eventType: 'message.created',
        payload: {
          metadata: {
            pendingAssistantMessageId: 'msg-assistant-1',
          },
        },
      }),
    ).toBe('msg-assistant-1');
  });

  it('falls back to event-derived client token', () => {
    expect(
      assistantClientTokenForEvent({
        eventId: 'evt_2',
        eventType: 'message.created',
      }),
    ).toBe('evt:evt_2');
  });
});
