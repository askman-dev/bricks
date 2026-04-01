import 'package:agent_core/src/providers/real_model_gateway.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:test/test.dart';

void main() {
  group('RealModelGateway', () {
    final gateway = RealModelGateway();

    test('returns synthetic output for test provider', () async {
      const settings = AgentSettings(provider: 'test', model: 'fake');
      final result =
          await gateway.generate(settings: settings, message: 'hello');
      expect(result, equals('Received: hello'));
    });

    test('throws for unsupported providers', () async {
      const settings = AgentSettings(provider: 'unknown', model: 'x');
      await expectLater(
        () => gateway.generate(settings: settings, message: 'hello'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
