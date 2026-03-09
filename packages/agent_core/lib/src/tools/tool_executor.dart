import 'package:agent_sdk_contract/agent_sdk_contract.dart';

/// Executes tool calls requested by the model.
///
/// Looks up registered tools by name and invokes them, respecting
/// the session's [AgentPermissions].
class ToolExecutor {
  final Map<String, _ToolHandler> _registry = {};

  /// Registers a tool handler.
  void register(String name, _ToolHandler handler) {
    _registry[name] = handler;
  }

  /// Executes a tool call and returns the result.
  ///
  /// Throws [UnknownToolException] if the tool is not registered.
  Future<Object?> execute(
    ToolCallStartEvent call,
    AgentPermissions permissions,
  ) async {
    final handler = _registry[call.toolName];
    if (handler == null) {
      throw UnknownToolException(call.toolName);
    }
    return handler(call.arguments, permissions);
  }
}

typedef _ToolHandler = Future<Object?> Function(
  Map<String, Object?> arguments,
  AgentPermissions permissions,
);

/// Thrown when an agent requests a tool that has not been registered.
class UnknownToolException implements Exception {
  UnknownToolException(this.toolName);
  final String toolName;

  @override
  String toString() => 'UnknownToolException: tool "$toolName" is not registered.';
}
