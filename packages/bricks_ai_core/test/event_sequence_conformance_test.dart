import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

import 'fixtures/fake_ai_model.dart';
import 'fixtures/fake_stream_outputs.dart';

void main() {
  const baseRequest = AiRequest(
    messages: [AiMessage(role: 'user', content: 'Hello')],
  );

  group('Event sequence conformance', () {
    // Case 8.1: plain text response sequence
    test('plain text response follows canonical sequence', () async {
      final events = plainTextSequence('Hello, world!');
      final model = FakeAiModel(
        providerId: 'fake',
        modelId: 'test',
        streamEvents: events,
      );

      final collected = await model.streamGenerate(baseRequest).toList();

      // 1. AiTextStartEvent
      expect(collected[0], isA<AiTextStartEvent>());
      // 2. one or more AiTextDeltaEvent
      expect(collected[1], isA<AiTextDeltaEvent>());
      expect((collected[1] as AiTextDeltaEvent).textDelta,
          equals('Hello, world!'));
      // 3. AiTextEndEvent
      expect(collected[2], isA<AiTextEndEvent>());
      // 4. AiFinishEvent
      expect(collected[3], isA<AiFinishEvent>());
      expect((collected[3] as AiFinishEvent).finishReason,
          equals(AiFinishReason.stop));
    });

    test('plain text multi-chunk response preserves all deltas', () async {
      final events = multiChunkTextSequence('Hello', ', world!');
      final model = FakeAiModel(
        providerId: 'fake',
        modelId: 'test',
        streamEvents: events,
      );

      final collected = await model.streamGenerate(baseRequest).toList();

      // 1. AiTextStartEvent
      expect(collected[0], isA<AiTextStartEvent>());
      // 2. first delta
      expect(collected[1], isA<AiTextDeltaEvent>());
      expect((collected[1] as AiTextDeltaEvent).textDelta, equals('Hello'));
      // 3. second delta
      expect(collected[2], isA<AiTextDeltaEvent>());
      expect((collected[2] as AiTextDeltaEvent).textDelta, equals(', world!'));
      // 4. AiTextEndEvent
      expect(collected[3], isA<AiTextEndEvent>());
      // 5. AiFinishEvent
      expect(collected[4], isA<AiFinishEvent>());
    });

    // Case 8.2: tool call sequence
    test('tool call sequence follows canonical ordering', () async {
      final events = toolCallSequence(
        callId: 'call-1',
        toolName: 'read_file',
        argsJsonDelta: '{"path": "/README.md"}',
      );
      final model = FakeAiModel(
        providerId: 'fake',
        modelId: 'test',
        streamEvents: events,
      );

      final collected = await model.streamGenerate(baseRequest).toList();

      // 1. AiToolCallStartEvent
      expect(collected[0], isA<AiToolCallStartEvent>());
      final start = collected[0] as AiToolCallStartEvent;
      expect(start.callId, equals('call-1'));
      expect(start.toolName, equals('read_file'));

      // 2. AiToolCallArgsDeltaEvent
      expect(collected[1], isA<AiToolCallArgsDeltaEvent>());
      final delta = collected[1] as AiToolCallArgsDeltaEvent;
      expect(delta.callId, equals('call-1'));
      expect(delta.argsJsonDelta, equals('{"path": "/README.md"}'));

      // 3. AiToolCallEndEvent
      expect(collected[2], isA<AiToolCallEndEvent>());
      expect((collected[2] as AiToolCallEndEvent).callId, equals('call-1'));

      // 4. AiFinishEvent with toolCall reason
      expect(collected[3], isA<AiFinishEvent>());
      expect((collected[3] as AiFinishEvent).finishReason,
          equals(AiFinishReason.toolCall));
    });

    // Case 8.3: error sequence
    // TODO(bricks_ai_core): finalize whether a stream error is represented as
    // an AiErrorEvent yielded before AiFinishEvent, or as a Dart stream error
    // (addError). This contract must be decided before provider implementation
    // starts. For now both mechanisms are shown and the test is skipped.
    test(
      'TODO: error sequence – AiErrorEvent vs stream error contract not yet '
      'finalized',
      () {
        // Option A (event-based): stream yields AiErrorEvent then closes.
        //   final events = [
        //     AiTextStartEvent(),
        //     AiErrorEvent(error: AiStructuredError(code: 'timeout', message: '...')),
        //   ];
        //   ...collect events...
        //   expect(collected.last, isA<AiErrorEvent>());
        //
        // Option B (exception-based): stream throws / addError.
        //   expect(
        //     () => model.streamGenerate(request).toList(),
        //     throwsA(isA<SomeProviderException>()),
        //   );
        //
        // The concrete contract must be chosen before provider implementation.
      },
      skip: 'Error-stream contract not yet finalized – see TODO comment.',
    );
  });
}
