import { describe, expect, it } from 'vitest';
import { extractIncomingText, shouldProcessEvent } from '../src/pluginRunner.js';

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
