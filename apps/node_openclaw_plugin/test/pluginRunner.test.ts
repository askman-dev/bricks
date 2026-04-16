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
  it('skips assistant/system events and same-user events', () => {
    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_1',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_1', displayName: 'user' } },
        },
        'u_1',
      ),
    ).toBe(false);

    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_2',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_2', displayName: 'assistant' } },
        },
        'u_1',
      ),
    ).toBe(false);
  });

  it('keeps user-created events from other users', () => {
    expect(
      shouldProcessEvent(
        {
          eventId: 'evt_3',
          eventType: 'message.created',
          payload: { sender: { userId: 'u_2', displayName: 'user' } },
        },
        'u_1',
      ),
    ).toBe(true);
  });
});
