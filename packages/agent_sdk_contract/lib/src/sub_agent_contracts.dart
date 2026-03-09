import 'tool_contracts.dart';

/// Describes a sub-agent that can be delegated work by the orchestrator.
class SubAgentSchema {
  const SubAgentSchema({
    required this.id,
    required this.name,
    required this.description,
    this.exposedTools = const [],
  });

  final String id;
  final String name;
  final String description;
  final List<ToolSchema> exposedTools;
}
