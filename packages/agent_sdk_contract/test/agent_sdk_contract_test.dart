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
}
