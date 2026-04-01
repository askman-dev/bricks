import 'dart:math';
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
        provider: 'test',
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
          provider: 'test',
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
      final complete = events.whereType<MessageCompleteEvent>().toList();
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

  group('ParticipantManager', () {
    late ParticipantManager manager;

    setUp(() => manager = ParticipantManager());

    test('starts with no participants', () {
      expect(manager.participants.participants, isEmpty);
    });

    test('addParticipant adds an agent', () {
      manager.addParticipant(
        const AgentParticipant(
          agentId: 'analyst',
          agentName: 'Analyst',
          probability: 0.3,
        ),
      );
      expect(manager.participants.participants, hasLength(1));
      expect(
        manager.participants.findById('analyst')!.probability,
        equals(0.3),
      );
    });

    test('addParticipant rejects duplicates', () {
      manager.addParticipant(
        const AgentParticipant(agentId: 'a', agentName: 'A'),
      );
      expect(
        () => manager.addParticipant(
          const AgentParticipant(agentId: 'a', agentName: 'A'),
        ),
        throwsArgumentError,
      );
    });

    test('removeParticipant removes an agent', () {
      manager.addParticipant(
        const AgentParticipant(agentId: 'a', agentName: 'A'),
      );
      manager.removeParticipant('a');
      expect(manager.participants.participants, isEmpty);
    });

    test('updateProbability changes probability', () {
      manager.addParticipant(
        const AgentParticipant(agentId: 'a', agentName: 'A', probability: 0.1),
      );
      manager.updateProbability('a', 0.7);
      expect(manager.participants.findById('a')!.probability, equals(0.7));
    });

    test('updateProbability rejects out-of-range values', () {
      manager.addParticipant(
        const AgentParticipant(agentId: 'a', agentName: 'A'),
      );
      expect(() => manager.updateProbability('a', 1.5),
          throwsA(isA<RangeError>()));
      expect(() => manager.updateProbability('a', -0.1),
          throwsA(isA<RangeError>()));
    });

    test('updateProbability throws for unknown agent', () {
      expect(
        () => manager.updateProbability('unknown', 0.5),
        throwsArgumentError,
      );
    });

    test('setEnabled toggles participant', () {
      manager.addParticipant(
        const AgentParticipant(agentId: 'a', agentName: 'A', isEnabled: true),
      );
      manager.setEnabled('a', false);
      expect(manager.participants.findById('a')!.isEnabled, isFalse);
      expect(manager.participants.active, isEmpty);
    });

    test('decideProactiveSpeakers returns agents based on probability', () {
      // Use a deterministic random that always returns 0.25
      final deterministicRandom = _FixedRandom(0.25);
      final mgr = ParticipantManager(random: deterministicRandom);

      mgr.addParticipant(
        const AgentParticipant(
          agentId: 'analyst',
          agentName: 'Analyst',
          probability: 0.3, // 0.25 < 0.3 → speaks
        ),
      );
      mgr.addParticipant(
        const AgentParticipant(
          agentId: 'critic',
          agentName: 'Critic',
          probability: 0.1, // 0.25 >= 0.1 → does not speak
        ),
      );
      mgr.addParticipant(
        const AgentParticipant(
          agentId: 'summarizer',
          agentName: 'Summarizer',
          isEnabled: false, // disabled → does not speak
          probability: 1.0,
        ),
      );

      final speakers = mgr.decideProactiveSpeakers();
      expect(speakers, equals(['analyst']));
    });

    test('decideProactiveSpeakers always includes probability 1.0 agents', () {
      final mgr = ParticipantManager();
      mgr.addParticipant(
        const AgentParticipant(
          agentId: 'always',
          agentName: 'Always',
          probability: 1.0,
        ),
      );
      // With probability 1.0, the agent should always speak.
      final speakers = mgr.decideProactiveSpeakers();
      expect(speakers, contains('always'));
    });

    test('decideProactiveSpeakers never includes probability 0.0 agents', () {
      final mgr = ParticipantManager();
      mgr.addParticipant(
        const AgentParticipant(
          agentId: 'silent',
          agentName: 'Silent',
          probability: 0.0,
        ),
      );
      final speakers = mgr.decideProactiveSpeakers();
      expect(speakers, isEmpty);
    });
  });
}

/// A [Random] that always returns a fixed value for [nextDouble].
class _FixedRandom implements Random {
  _FixedRandom(this._value);
  final double _value;

  @override
  double nextDouble() => _value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
