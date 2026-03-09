import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:test_harness/test_harness.dart';
import 'package:test/test.dart';

void main() {
  group('FakeAgentClient', () {
    test('isReady returns configured value', () async {
      final client = FakeAgentClient(readyResult: true);
      expect(await client.isReady(), isTrue);

      final notReady = FakeAgentClient(readyResult: false);
      expect(await notReady.isReady(), isFalse);
    });

    test('createSession returns a FakeAgentSession', () {
      final client = FakeAgentClient();
      final session = client.createSession(
        const AgentSettings(provider: 'test', model: 'fake'),
      );
      expect(session, isA<FakeAgentSession>());
      expect(client.createdSessions, hasLength(1));
    });
  });

  group('FakeAgentSession', () {
    test('sendMessage emits canned response and RunCompleteEvent', () async {
      final client = FakeAgentClient(cannedResponse: 'Hello from fake!');
      final session = client.createSession(
        const AgentSettings(provider: 'test', model: 'fake'),
      );

      final events = await session.sendMessage('Hi').toList();

      expect(events.whereType<TextDeltaEvent>().first.delta,
          equals('Hello from fake!'));
      expect(events.last, isA<RunCompleteEvent>());
    });

    test('isRunning is false after completion', () async {
      final client = FakeAgentClient();
      final session = client.createSession(
        const AgentSettings(provider: 'test', model: 'fake'),
      );
      await session.sendMessage('test').toList();
      expect(session.isRunning, isFalse);
    });

    test('settings are stored and accessible for test assertions', () {
      final client = FakeAgentClient();
      const settings = AgentSettings(provider: 'test', model: 'fake-large');
      final session = client.createSession(settings) as FakeAgentSession;
      expect(session.settings.model, equals('fake-large'));
    });
  });

  group('FakeWorkspace', () {
    test('create builds workspace structure', () async {
      final fake = await FakeWorkspace.create();
      addTearDown(fake.dispose);

      await fake.ensureDefault();
      expect(fake.defaultWorkspace.name, equals('default'));
      expect(fake.defaultWorkspace.isDefault, isTrue);
    });
  });

  group('SampleProjects', () {
    test('helloWorld returns a Project with correct properties', () {
      final project = SampleProjects.helloWorld();
      expect(project.name, equals('hello-world'));
      expect(project.type, equals(ProjectType.website));
    });
  });
}
