import 'ai_message.dart';

/// Describes a tool that can be invoked by the AI model.
class AiToolSchema {
  const AiToolSchema({
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

/// An immutable value object that describes a single inference request.
///
/// All fields that are not required have sensible defaults so that callers
/// only need to provide what they explicitly care about.
class AiRequest {
  const AiRequest({
    required this.messages,
    this.tools = const [],
    this.toolChoice,
    this.temperature,
    this.maxOutputTokens,
    this.systemInstruction,
    this.providerOptions = const {},
    this.metadata = const {},
  });

  /// The conversation history to send to the model.
  final List<AiMessage> messages;

  /// Tool schemas available to the model during this request.
  final List<AiToolSchema> tools;

  /// Controls tool invocation strategy (e.g. 'auto', 'required', or a specific
  /// tool name). Null defers to the provider's default.
  final String? toolChoice;

  /// Sampling temperature. Null defers to the provider's default.
  final double? temperature;

  /// Maximum number of output tokens. Null defers to the provider's default.
  final int? maxOutputTokens;

  /// System-level instruction prepended to the conversation. Null means none.
  final String? systemInstruction;

  /// Provider-specific options that pass through the core layer untouched.
  ///
  /// Keys and values are interpreted by the concrete provider implementation.
  /// The core layer never reads, modifies, or validates this map.
  final Map<String, Object?> providerOptions;

  /// Arbitrary caller-supplied metadata (e.g. tracing IDs, request labels).
  ///
  /// The core layer passes this through unchanged.
  final Map<String, Object?> metadata;
}
