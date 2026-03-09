import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

import 'fixtures/fake_ai_model.dart';
import 'fixtures/fake_stream_outputs.dart';

void main() {
  const baseRequest = AiRequest(
    messages: [AiMessage(role: 'user', content: 'Hello')],
  );

  group('AiModel contract', () {
    // Case 7.1: model exposes provider id and model id
    test('exposes non-empty providerId and modelId', () {
      final model = FakeAiModel(
        providerId: 'anthropic',
        modelId: 'claude-sonnet-4-5',
      );

      expect(model.providerId, isNotEmpty);
      expect(model.modelId, isNotEmpty);
      expect(model.providerId, equals('anthropic'));
      expect(model.modelId, equals('claude-sonnet-4-5'));
    });

    // Case 7.2: generate returns AiGenerateResult
    test('generate() returns the configured AiGenerateResult', () async {
      const expected = AiGenerateResult(
        output: [AiTextBlock('The answer is 42.')],
        finishReason: AiFinishReason.stop,
      );
      final model = FakeAiModel(
        providerId: 'openai',
        modelId: 'gpt-4.1-mini',
        generateResult: expected,
      );

      final result = await model.generate(baseRequest);

      expect(result, isA<AiGenerateResult>());
      expect(result, same(expected));
    });

    // Case 7.3: streamGenerate emits normalized events
    test('streamGenerate emits only AiStreamEvent subclasses', () async {
      final events = plainTextSequence('hello');
      final model = FakeAiModel(
        providerId: 'openai',
        modelId: 'gpt-4.1-mini',
        streamEvents: events,
      );

      final collected = await model.streamGenerate(baseRequest).toList();

      for (final event in collected) {
        expect(event, isA<AiStreamEvent>());
      }
    });

    // Case 7.4: streamGenerate preserves order
    test('streamGenerate yields events in exact emission order', () async {
      final events = [
        const AiTextStartEvent(),
        const AiTextDeltaEvent('chunk-1'),
        const AiToolCallStartEvent(callId: 'c1', toolName: 'search'),
        const AiToolCallArgsDeltaEvent(callId: 'c1', argsJsonDelta: '{"q":'),
        const AiToolCallEndEvent(callId: 'c1'),
        const AiFinishEvent(finishReason: AiFinishReason.toolCall),
      ];
      final model = FakeAiModel(
        providerId: 'openai',
        modelId: 'gpt-4.1-mini',
        streamEvents: events,
      );

      final collected = await model.streamGenerate(baseRequest).toList();

      expect(collected, hasLength(events.length));
      for (var i = 0; i < events.length; i++) {
        expect(collected[i], same(events[i]));
      }
    });

    // Case 7.5: capabilities exposed independently of execution
    test('capabilities can be read without starting a request', () {
      final model = FakeAiModel(
        providerId: 'openai',
        modelId: 'gpt-4.1-mini',
        capabilities: const AiModelCapabilities(
          supportsStreaming: true,
          supportsTools: true,
        ),
      );

      // No request is started – capabilities must be synchronously readable.
      expect(model.capabilities, isA<AiModelCapabilities>());
      expect(model.capabilities.supportsStreaming, isTrue);
      expect(model.capabilities.supportsTools, isTrue);
      expect(model.capabilities.supportsVision, isFalse);
      expect(model.receivedRequests, isEmpty);
    });
  });
}
