import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('AiGenerateResult', () {
    // Case 2.1: constructs with required fields
    test('constructs with required output and finishReason', () {
      const result = AiGenerateResult(
        output: [AiTextBlock('Hello, world!')],
        finishReason: AiFinishReason.stop,
      );

      expect(result.output, hasLength(1));
      expect(result.finishReason, equals(AiFinishReason.stop));
      expect(result.usage, isNull);
      expect(result.metadata, isEmpty);
      expect(result.rawResponse, isNull);
    });

    // Case 2.2: preserves usage and metadata
    test('preserves usage and metadata', () {
      const usage = AiUsage(
        inputTokens: 100,
        outputTokens: 50,
        totalTokens: 150,
      );
      const metadata = {'requestId': 'req-001', 'region': 'us-east-1'};

      const result = AiGenerateResult(
        output: [AiTextBlock('response')],
        finishReason: AiFinishReason.stop,
        usage: usage,
        metadata: metadata,
      );

      expect(result.usage, isNotNull);
      expect(result.usage!.inputTokens, equals(100));
      expect(result.usage!.outputTokens, equals(50));
      expect(result.usage!.totalTokens, equals(150));
      expect(result.metadata['requestId'], equals('req-001'));
      expect(result.metadata['region'], equals('us-east-1'));
    });

    // Case 2.3: preserves raw response escape hatch
    test('stores rawResponse without interpretation', () {
      final fakeVendorDto = {'choices': [], 'model': 'gpt-4.1-mini'};

      final result = AiGenerateResult(
        output: const [AiTextBlock('response')],
        finishReason: AiFinishReason.stop,
        rawResponse: fakeVendorDto,
      );

      expect(result.rawResponse, same(fakeVendorDto));
      expect(result.rawResponse, isA<Map<String, Object?>>());
    });

    // Case 2.4: supports mixed output blocks
    test('preserves ordering of mixed output blocks exactly', () {
      const output = [
        AiTextBlock('Before the tool call.'),
        AiToolCallBlock(
          callId: 'call-1',
          toolName: 'read_file',
          argsJson: '{"path": "/README.md"}',
        ),
        AiTextBlock('After the tool call.'),
      ];

      const result = AiGenerateResult(
        output: output,
        finishReason: AiFinishReason.toolCall,
      );

      expect(result.output, hasLength(3));
      expect(result.output[0], isA<AiTextBlock>());
      expect((result.output[0] as AiTextBlock).text,
          equals('Before the tool call.'));
      expect(result.output[1], isA<AiToolCallBlock>());
      expect((result.output[1] as AiToolCallBlock).toolName,
          equals('read_file'));
      expect(result.output[2], isA<AiTextBlock>());
      expect((result.output[2] as AiTextBlock).text,
          equals('After the tool call.'));
    });
  });
}
