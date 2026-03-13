/// Defines a user-created sub-agent that can be selected via the `@` menu.
///
/// Agent definitions are stored as local `.md` files with YAML front-matter.
/// See [AgentFileCodec] for the on-disk format.
class AgentDefinition {
  AgentDefinition({
    required this.name,
    required this.description,
    required this.model,
    required this.systemPrompt,
    this.tools = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Lowercase-hyphen identifier, unique across agents.
  final String name;

  /// Short human-readable description (≤ 100 characters).
  final String description;

  /// Model identifier (e.g. `gemini-flash`, `sonnet`).
  final String model;

  /// Optional tool whitelist. Empty means no tool restrictions.
  final List<String> tools;

  /// The system prompt that configures the agent's behaviour.
  final String systemPrompt;

  /// Timestamp when this agent was first created.
  final DateTime createdAt;

  /// The set of allowed model identifiers.
  static const allowedModels = {
    'gemini-flash',
    'gemini-pro',
    'haiku',
    'sonnet',
    'opus',
  };

  // ── Validation ──────────────────────────────────────────────────────

  static final _namePattern = RegExp(r'^[a-z][a-z0-9\-]*$');

  /// Validates this definition against the rules from the spec.
  ///
  /// Returns a list of human-readable error strings.
  /// An empty list means the definition is valid.
  List<String> validate() {
    final errors = <String>[];
    if (name.isEmpty) {
      errors.add('name is required');
    } else if (!_namePattern.hasMatch(name)) {
      errors.add('name must be lowercase letters, digits, and hyphens');
    }
    if (description.isEmpty) {
      errors.add('description is required');
    } else if (description.length > 100) {
      errors.add('description must be ≤ 100 characters');
    }
    if (!allowedModels.contains(model)) {
      errors.add(
        'model must be one of: ${allowedModels.join(', ')}',
      );
    }
    if (systemPrompt.trim().isEmpty) {
      errors.add('prompt is required');
    }
    return errors;
  }

  // ── Serialisation ───────────────────────────────────────────────────

  /// Serialises to a JSON-compatible map.
  Map<String, Object?> toMap() => {
        'name': name,
        'description': description,
        'model': model,
        'tools': tools,
        'system_prompt': systemPrompt,
        'created_at': createdAt.toIso8601String(),
      };

  /// Deserialises from a JSON-compatible map.
  factory AgentDefinition.fromMap(Map<String, Object?> map) {
    return AgentDefinition(
      name: map['name'] as String,
      description: map['description'] as String,
      model: map['model'] as String,
      systemPrompt: map['system_prompt'] as String,
      tools: (map['tools'] as List<Object?>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
