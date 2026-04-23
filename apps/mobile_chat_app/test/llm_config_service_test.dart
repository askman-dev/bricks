import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/settings/llm_config_service.dart';

void main() {
  group('LlmConfigService base URL', () {
    test('documents the production native release default', () {
      expect(
        LlmConfigService.productionApiBaseUrl,
        equals('https://bricks.askman.dev'),
      );
    });

    test('uses localhost for non-web non-release test builds', () {
      expect(
        LlmConfigService.resolveBaseUrl(),
        equals('http://localhost:3000'),
      );
    });
  });
}
