import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:test/test.dart';

void main() {
  group('AgentCoreClient', () {
    late AgentCoreClient client;

    setUp(() => client = AgentCoreClient());

    test('isReady returns true', () async {
      expect(await client.isReady(), isTrue);
    });

    test('createSession returns an AgentSession', () {
      const settings = AgentSettings(
        provider: 'anthropic',
        model: 'claude-sonnet-4-5',
      );
      final session = client.createSession(settings);
      expect(session, isA<AgentSession>());
      expect(session.sessionId, isNotEmpty);
      expect(session.isRunning, isFalse);
    });
  });

  group('AgentSessionImpl', () {
    late AgentCoreClient client;
    late AgentSession session;

    setUp(() {
      client = AgentCoreClient();
      session = client.createSession(
        const AgentSettings(
          provider: 'anthropic',
          model: 'claude-sonnet-4-5',
        ),
      );
    });

    tearDown(() => session.dispose());

    test('sendMessage emits events and completes', () async {
      final events = await session.sendMessage('Hello').toList();

      expect(events, isNotEmpty);
      expect(events.last, isA<RunCompleteEvent>());
    });

    test('sendMessage emits MessageCompleteEvent', () async {
      final events = await session.sendMessage('Hi').toList();
      final complete =
          events.whereType<MessageCompleteEvent>().toList();
      expect(complete, hasLength(1));
    });

    test('session is not running after completion', () async {
      await session.sendMessage('ping').toList();
      expect(session.isRunning, isFalse);
    });

    test('RunCompleteEvent has cancelled=false on normal completion', () async {
      final events = await session.sendMessage('hello').toList();
      final complete = events.whereType<RunCompleteEvent>().single;
      expect(complete.cancelled, isFalse);
    });

    test('cancel on idle session is a no-op', () async {
      expect(session.isRunning, isFalse);
      await expectLater(session.cancel(), completes);
      expect(session.isRunning, isFalse);
    });
  });
}
