import 'agent_definition.dart';

/// Encodes and decodes [AgentDefinition] objects to and from the `.md` file
/// format used for agent storage.
///
/// The file format uses YAML front-matter delimited by `---` followed by the
/// system prompt in Markdown:
///
/// ```markdown
/// ---
/// name: my-agent
/// description: Used for specific scenarios
/// model: gemini-flash
/// tools: Read, Bash
/// created_at: 2026-03-13T07:15:00Z
/// ---
///
/// ## System Prompt
///
/// Write agent instructions here...
/// ```
class AgentFileCodec {
  AgentFileCodec._();

  /// Encodes an [AgentDefinition] into the `.md` file format.
  static String encode(AgentDefinition agent) {
    final buffer = StringBuffer()..writeln('---');

    buffer.writeln('name: ${agent.name}');
    buffer.writeln('description: ${agent.description}');
    buffer.writeln('model: ${agent.model}');
    if (agent.tools.isNotEmpty) {
      buffer.writeln('tools: ${agent.tools.join(', ')}');
    }
    buffer.writeln('created_at: ${agent.createdAt.toIso8601String()}');

    buffer.writeln('---');
    buffer.writeln();
    buffer.write(agent.systemPrompt);

    // Ensure trailing newline
    final result = buffer.toString();
    return result.endsWith('\n') ? result : '$result\n';
  }

  /// Decodes the `.md` file format into an [AgentDefinition].
  ///
  /// Throws [FormatException] if the content does not have valid front-matter.
  static AgentDefinition decode(String content) {
    final trimmed = content.trimLeft();
    if (!trimmed.startsWith('---')) {
      throw const FormatException(
        'Agent file must start with YAML front-matter (---).',
      );
    }

    // Find the closing '---' delimiter
    final afterOpening = trimmed.indexOf('\n');
    if (afterOpening == -1) {
      throw const FormatException(
        'Agent file front-matter is missing the closing --- delimiter.',
      );
    }

    final closingIndex = trimmed.indexOf('\n---', afterOpening);
    if (closingIndex == -1) {
      throw const FormatException(
        'Agent file front-matter is missing the closing --- delimiter.',
      );
    }

    final frontMatterBlock =
        trimmed.substring(afterOpening + 1, closingIndex).trim();
    final bodyStart = closingIndex + 4; // skip '\n---'
    final body =
        bodyStart < trimmed.length ? trimmed.substring(bodyStart) : '';
    final systemPrompt = _trimBody(body);

    // Parse the simple YAML key-value pairs
    final fields = _parseFrontMatter(frontMatterBlock);

    final name = fields['name'];
    if (name == null || name.isEmpty) {
      throw const FormatException('Front-matter is missing required "name".');
    }

    final description = fields['description'] ?? '';
    final model = fields['model'] ?? '';
    final toolsRaw = fields['tools'] ?? '';
    final tools = toolsRaw.isEmpty
        ? <String>[]
        : toolsRaw.split(',').map((t) => t.trim()).toList();
    final createdAtRaw = fields['created_at'];

    DateTime? createdAt;
    if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    return AgentDefinition(
      name: name,
      description: description,
      model: model,
      tools: tools,
      systemPrompt: systemPrompt,
      createdAt: createdAt,
    );
  }

  /// Parses simple YAML-like `key: value` lines from front-matter.
  static Map<String, String> _parseFrontMatter(String block) {
    final map = <String, String>{};
    for (final line in block.split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();
      if (key.isNotEmpty) {
        map[key] = value;
      }
    }
    return map;
  }

  /// Trims leading/trailing whitespace from the body while preserving a
  /// single trailing newline.
  static String _trimBody(String body) {
    // Remove leading blank lines but keep internal formatting
    var result = body;
    while (result.startsWith('\n')) {
      result = result.substring(1);
    }
    // Remove trailing whitespace, then add a single newline
    result = result.trimRight();
    return result;
  }
}
