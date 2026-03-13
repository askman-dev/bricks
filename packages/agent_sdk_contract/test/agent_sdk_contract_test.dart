import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:test/test.dart';

void main() {
  group('AgentSettings', () {
    test('has sensible defaults', () {
      const settings = AgentSettings(
        provider: 'anthropic',
        model: 'claude-sonnet-4-5',
      );
      expect(settings.maxContextTokens, equals(32768));
      expect(settings.maxToolCallsPerTurn, equals(20));
      expect(settings.streamEvents, isTrue);
      expect(settings.permissions.allowFilesystemRead, isTrue);
      expect(settings.permissions.allowFilesystemWrite, isFalse);
    });
  });

  group('AgentSessionEvent subtypes', () {
    test('TextDeltaEvent carries delta', () {
      const event = TextDeltaEvent('Hello');
      expect(event.delta, equals('Hello'));
    });

    test('ToolCallStartEvent carries name and arguments', () {
      const event = ToolCallStartEvent(
        callId: 'call-1',
        toolName: 'read_file',
        arguments: {'path': '/index.html'},
      );
      expect(event.toolName, equals('read_file'));
      expect(event.arguments['path'], equals('/index.html'));
    });

    test('AgentErrorEvent defaults isFatal to false', () {
      const event = AgentErrorEvent(message: 'oops');
      expect(event.isFatal, isFalse);
    });

    test('RunCompleteEvent defaults cancelled to false', () {
      const event = RunCompleteEvent();
      expect(event.cancelled, isFalse);
    });
  });

  group('ToolSchema', () {
    test('holds name, description, inputSchema', () {
      const schema = ToolSchema(
        name: 'write_file',
        description: 'Write content to a file',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string'},
            'content': {'type': 'string'},
          },
          'required': ['path', 'content'],
        },
      );
      expect(schema.name, equals('write_file'));
      expect(schema.inputSchema['type'], equals('object'));
    });
  });

  group('AgentParticipant', () {
    test('has sensible defaults', () {
      const p = AgentParticipant(
        agentId: 'analyst',
        agentName: 'Analyst',
      );
      expect(p.isEnabled, isTrue);
      expect(p.probability, equals(0.0));
    });

    test('copyWith replaces specified fields', () {
      const p = AgentParticipant(
        agentId: 'analyst',
        agentName: 'Analyst',
        probability: 0.3,
      );
      final updated = p.copyWith(probability: 0.8, isEnabled: false);
      expect(updated.probability, equals(0.8));
      expect(updated.isEnabled, isFalse);
      expect(updated.agentId, equals('analyst'));
    });

    test('toMap / fromMap round-trip', () {
      const p = AgentParticipant(
        agentId: 'critic',
        agentName: 'Critic',
        isEnabled: true,
        probability: 0.5,
      );
      final restored = AgentParticipant.fromMap(p.toMap());
      expect(restored.agentId, equals('critic'));
      expect(restored.agentName, equals('Critic'));
      expect(restored.isEnabled, isTrue);
      expect(restored.probability, equals(0.5));
    });

    test('equality is based on agentId', () {
      const a = AgentParticipant(agentId: 'x', agentName: 'X');
      const b = AgentParticipant(
        agentId: 'x',
        agentName: 'X2',
        probability: 0.9,
      );
      expect(a, equals(b));
    });
  });

  group('SessionParticipants', () {
    test('active returns only enabled participants', () {
      const sp = SessionParticipants(participants: [
        AgentParticipant(agentId: 'a', agentName: 'A', isEnabled: true),
        AgentParticipant(agentId: 'b', agentName: 'B', isEnabled: false),
        AgentParticipant(agentId: 'c', agentName: 'C', isEnabled: true),
      ]);
      final active = sp.active;
      expect(active, hasLength(2));
      expect(active.map((p) => p.agentId), containsAll(['a', 'c']));
    });

    test('findById returns participant or null', () {
      const sp = SessionParticipants(participants: [
        AgentParticipant(agentId: 'a', agentName: 'A'),
      ]);
      expect(sp.findById('a'), isNotNull);
      expect(sp.findById('z'), isNull);
    });

    test('toMap / fromMap round-trip', () {
      const sp = SessionParticipants(participants: [
        AgentParticipant(
          agentId: 'analyst',
          agentName: 'Analyst',
          probability: 0.3,
        ),
      ]);
      final restored = SessionParticipants.fromMap(sp.toMap());
      expect(restored.participants, hasLength(1));
      expect(restored.participants.first.agentId, equals('analyst'));
      expect(restored.participants.first.probability, equals(0.3));
    });
  });
}
