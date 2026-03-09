import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('AiRequest', () {
    // Case 1.1: constructs with minimal required fields
    test('constructs with only messages and applies default values', () {
      final request = AiRequest(
        messages: const [AiMessage(role: 'user', content: 'Hello')],
      );

      expect(request.messages, hasLength(1));
      expect(request.tools, isEmpty);
      expect(request.providerOptions, isEmpty);
      expect(request.metadata, isEmpty);
      expect(request.toolChoice, isNull);
      expect(request.temperature, isNull);
      expect(request.maxOutputTokens, isNull);
      expect(request.systemInstruction, isNull);
    });

    // Case 1.2: preserves optional fields
    test('preserves optional fields exactly', () {
      final request = AiRequest(
        messages: const [AiMessage(role: 'user', content: 'Hi')],
        toolChoice: 'required',
        temperature: 0.7,
        maxOutputTokens: 512,
        systemInstruction: 'You are a helpful assistant.',
      );

      expect(request.toolChoice, equals('required'));
      expect(request.temperature, equals(0.7));
      expect(request.maxOutputTokens, equals(512));
      expect(request.systemInstruction, equals('You are a helpful assistant.'));
    });

    // Case 1.3: preserves provider-specific options
    test('preserves provider-specific options without normalization', () {
      final request = AiRequest(
        messages: const [AiMessage(role: 'user', content: 'Test')],
        providerOptions: const {
          'thinkingBudget': 1024,
          'responseFormat': 'json',
        },
      );

      expect(request.providerOptions['thinkingBudget'], equals(1024));
      expect(request.providerOptions['responseFormat'], equals('json'));
      expect(request.providerOptions, hasLength(2));
    });

    // Case 1.4: preserves metadata
    test('preserves metadata unchanged', () {
      const tracingMetadata = {
        'traceId': 'abc-123',
        'spanId': 'span-456',
        'userId': 'user-789',
      };

      final request = AiRequest(
        messages: const [AiMessage(role: 'user', content: 'Test')],
        metadata: tracingMetadata,
      );

      expect(request.metadata, equals(tracingMetadata));
      expect(request.metadata['traceId'], equals('abc-123'));
      expect(request.metadata['spanId'], equals('span-456'));
      expect(request.metadata['userId'], equals('user-789'));
    });
  });
}
