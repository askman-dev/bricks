import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('AiStreamEvent', () {
    // Case 3.1: text delta event carries exact text
    test('AiTextDeltaEvent carries exact textDelta', () {
      const event = AiTextDeltaEvent('hel');
      expect(event.textDelta, equals('hel'));
      expect(event, isA<AiStreamEvent>());
    });

    // Case 3.2: reasoning delta event carries exact text
    test('AiReasoningDeltaEvent carries exact textDelta', () {
      const event = AiReasoningDeltaEvent('step 1');
      expect(event.textDelta, equals('step 1'));
      expect(event, isA<AiStreamEvent>());
    });

    // Case 3.3: tool call start includes stable identity
    test('AiToolCallStartEvent preserves callId and toolName', () {
      const event = AiToolCallStartEvent(callId: 'c1', toolName: 'read_file');
      expect(event.callId, equals('c1'));
      expect(event.toolName, equals('read_file'));
      expect(event, isA<AiStreamEvent>());
    });

    // Case 3.4: tool args delta preserves raw JSON fragment
    test('AiToolCallArgsDeltaEvent preserves raw JSON fragment exactly', () {
      const event = AiToolCallArgsDeltaEvent(
        callId: 'c1',
        argsJsonDelta: '{"path":',
      );
      expect(event.callId, equals('c1'));
      expect(event.argsJsonDelta, equals('{"path":'));
    });

    // Case 3.5: finish event preserves reason
    test('AiFinishEvent preserves finishReason', () {
      const event = AiFinishEvent(finishReason: AiFinishReason.stop);
      expect(event.finishReason, equals(AiFinishReason.stop));
      expect(event, isA<AiStreamEvent>());
    });

    test('AiFinishEvent preserves toolCall finish reason', () {
      const event = AiFinishEvent(finishReason: AiFinishReason.toolCall);
      expect(event.finishReason, equals(AiFinishReason.toolCall));
    });

    // Case 3.6: error event wraps structured error
    test('AiErrorEvent preserves structured error object', () {
      const error = AiStructuredError(
        code: 'rate_limit',
        message: 'Too many requests',
        details: {'retryAfter': 30},
      );
      const event = AiErrorEvent(error: error);

      expect(event.error, same(error));
      expect(event.error.code, equals('rate_limit'));
      expect(event.error.message, equals('Too many requests'));
      expect(event.error.details, isA<Map>());
      expect(event, isA<AiStreamEvent>());
    });

    test('AiTextStartEvent and AiTextEndEvent are AiStreamEvents', () {
      expect(const AiTextStartEvent(), isA<AiStreamEvent>());
      expect(const AiTextEndEvent(), isA<AiStreamEvent>());
    });

    test('AiToolCallEndEvent preserves callId', () {
      const event = AiToolCallEndEvent(callId: 'c2');
      expect(event.callId, equals('c2'));
      expect(event, isA<AiStreamEvent>());
    });

    test('AiUsageEvent preserves usage', () {
      const usage = AiUsage(inputTokens: 10, outputTokens: 5);
      const event = AiUsageEvent(usage);
      expect(event.usage.inputTokens, equals(10));
      expect(event.usage.outputTokens, equals(5));
      expect(event, isA<AiStreamEvent>());
    });
  });
}
