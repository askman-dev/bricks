import 'package:chat_domain/chat_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AgentDefinition', () {
    test('toMap / fromMap round-trip', () {
      final agent = AgentDefinition(
        name: 'my-agent',
        description: 'Test agent',
        model: 'sonnet',
        systemPrompt: 'You are a helpful assistant.',
        tools: ['Read', 'Bash'],
        createdAt: DateTime.utc(2026, 3, 13),
      );

      final restored = AgentDefinition.fromMap(agent.toMap());
      expect(restored.name, equals('my-agent'));
      expect(restored.description, equals('Test agent'));
      expect(restored.model, equals('sonnet'));
      expect(restored.systemPrompt, equals('You are a helpful assistant.'));
      expect(restored.tools, equals(['Read', 'Bash']));
      expect(restored.createdAt, equals(DateTime.utc(2026, 3, 13)));
    });

    test('toMap / fromMap round-trip with no tools', () {
      final agent = AgentDefinition(
        name: 'simple',
        description: 'No tools',
        model: 'haiku',
        systemPrompt: 'Hello',
      );

      final restored = AgentDefinition.fromMap(agent.toMap());
      expect(restored.tools, isEmpty);
    });

    group('validation', () {
      AgentDefinition validAgent({
        String name = 'valid-name',
        String description = 'A valid description',
        String model = 'sonnet',
        String systemPrompt = 'Some prompt',
      }) {
        return AgentDefinition(
          name: name,
          description: description,
          model: model,
          systemPrompt: systemPrompt,
        );
      }

      test('valid agent has no errors', () {
        expect(validAgent().validate(), isEmpty);
      });

      test('rejects empty name', () {
        final errors = validAgent(name: '').validate();
        expect(errors, contains('name is required'));
      });

      test('rejects name with uppercase', () {
        final errors = validAgent(name: 'MyAgent').validate();
        expect(errors, contains('name must be lowercase letters, digits, and hyphens'));
      });

      test('rejects name with spaces', () {
        final errors = validAgent(name: 'my agent').validate();
        expect(errors, contains('name must be lowercase letters, digits, and hyphens'));
      });

      test('rejects name starting with hyphen', () {
        final errors = validAgent(name: '-agent').validate();
        expect(errors, contains('name must be lowercase letters, digits, and hyphens'));
      });

      test('accepts name with digits', () {
        expect(validAgent(name: 'agent-2').validate(), isEmpty);
      });

      test('rejects empty description', () {
        final errors = validAgent(description: '').validate();
        expect(errors, contains('description is required'));
      });

      test('rejects description over 100 chars', () {
        final errors = validAgent(description: 'a' * 101).validate();
        expect(errors, contains('description must be ≤ 100 characters'));
      });

      test('accepts description of exactly 100 chars', () {
        expect(validAgent(description: 'a' * 100).validate(), isEmpty);
      });

      test('rejects unknown model', () {
        final errors = validAgent(model: 'gpt-99').validate();
        expect(
          errors,
          contains(startsWith('model must be one of:')),
        );
      });

      test('rejects empty prompt', () {
        final errors = validAgent(systemPrompt: '  ').validate();
        expect(errors, contains('prompt is required'));
      });

      test('returns multiple errors at once', () {
        final agent = AgentDefinition(
          name: '',
          description: '',
          model: 'unknown',
          systemPrompt: '',
        );
        final errors = agent.validate();
        expect(errors.length, greaterThanOrEqualTo(3));
      });
    });
  });

  group('AgentFileCodec', () {
    test('encode produces valid markdown with front-matter', () {
      final agent = AgentDefinition(
        name: 'my-agent',
        description: 'Used for specific scenarios',
        model: 'gemini-flash',
        tools: ['Read', 'Bash'],
        systemPrompt: '## System Prompt\n\nWrite agent instructions here...',
        createdAt: DateTime.utc(2026, 3, 13, 7, 15),
      );

      final content = AgentFileCodec.encode(agent);
      expect(content, startsWith('---\n'));
      expect(content, contains('name: my-agent'));
      expect(content, contains('description: Used for specific scenarios'));
      expect(content, contains('model: gemini-flash'));
      expect(content, contains('tools: Read, Bash'));
      expect(content, contains('created_at:'));
      expect(content, contains('---\n'));
      expect(content, contains('## System Prompt'));
      expect(content, endsWith('\n'));
    });

    test('encode omits tools line when tools is empty', () {
      final agent = AgentDefinition(
        name: 'no-tools',
        description: 'No tools agent',
        model: 'sonnet',
        systemPrompt: 'Hello',
      );

      final content = AgentFileCodec.encode(agent);
      expect(content, isNot(contains('tools:')));
    });

    test('decode parses valid agent file', () {
      const content = '''---
name: my-agent
description: Used for specific scenarios
model: gemini-flash
tools: Read, Bash
created_at: 2026-03-13T07:15:00.000Z
---

## System Prompt

Write agent instructions here...
''';

      final agent = AgentFileCodec.decode(content);
      expect(agent.name, equals('my-agent'));
      expect(agent.description, equals('Used for specific scenarios'));
      expect(agent.model, equals('gemini-flash'));
      expect(agent.tools, equals(['Read', 'Bash']));
      expect(agent.systemPrompt, equals('## System Prompt\n\nWrite agent instructions here...'));
      expect(agent.createdAt, equals(DateTime.utc(2026, 3, 13, 7, 15)));
    });

    test('decode parses file without tools', () {
      const content = '''---
name: simple
description: Simple agent
model: haiku
created_at: 2026-01-01T00:00:00.000Z
---

Just a simple prompt.
''';

      final agent = AgentFileCodec.decode(content);
      expect(agent.name, equals('simple'));
      expect(agent.tools, isEmpty);
      expect(agent.systemPrompt, equals('Just a simple prompt.'));
    });

    test('encode → decode round-trip preserves data', () {
      final original = AgentDefinition(
        name: 'round-trip',
        description: 'Test round trip',
        model: 'opus',
        tools: ['Read'],
        systemPrompt: 'You are an expert coder.\n\nHelp the user write code.',
        createdAt: DateTime.utc(2026, 6, 15, 12, 30),
      );

      final encoded = AgentFileCodec.encode(original);
      final decoded = AgentFileCodec.decode(encoded);

      expect(decoded.name, equals(original.name));
      expect(decoded.description, equals(original.description));
      expect(decoded.model, equals(original.model));
      expect(decoded.tools, equals(original.tools));
      expect(decoded.systemPrompt, equals(original.systemPrompt));
      expect(decoded.createdAt, equals(original.createdAt));
    });

    test('decode throws FormatException for missing front-matter', () {
      expect(
        () => AgentFileCodec.decode('No front matter here'),
        throwsFormatException,
      );
    });

    test('decode throws FormatException for missing closing delimiter', () {
      expect(
        () => AgentFileCodec.decode('---\nname: broken\n'),
        throwsFormatException,
      );
    });

    test('decode throws FormatException for missing name', () {
      expect(
        () => AgentFileCodec.decode('---\ndescription: no name\n---\nBody'),
        throwsFormatException,
      );
    });
  });
}
