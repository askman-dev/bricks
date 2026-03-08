/// Describes a tool that the agent can call.
class ToolSchema {
  const ToolSchema({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  /// The unique name of the tool (snake_case).
  final String name;

  /// Human-readable description used by the model to decide when to call this tool.
  final String description;

  /// JSON Schema object describing the tool's input parameters.
  final Map<String, Object?> inputSchema;
}
