import 'tool_contracts.dart';

/// Manifest describing a skill that can be loaded by the agent.
class SkillManifest {
  const SkillManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    this.tools = const [],
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final List<ToolSchema> tools;
}
