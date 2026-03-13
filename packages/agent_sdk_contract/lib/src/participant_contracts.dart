import 'package:meta/meta.dart';

/// Represents an agent participating in a multi-agent session.
///
/// Wraps the agent's identity (shared with issue #23's agent definitions)
/// and adds participation-specific settings: whether the agent is enabled
/// and the probability of proactive speaking.
///
/// The agent identity fields ([agentId], [agentName]) correspond to the
/// `name` in #23's agent `.md` files, keeping a single source of truth.
class AgentParticipant {
  const AgentParticipant({
    required this.agentId,
    required this.agentName,
    this.isEnabled = true,
    this.probability = 0.0,
  })  : assert(probability >= 0.0 && probability <= 1.0,
            'probability must be between 0.0 and 1.0');

  /// Unique identifier matching the agent definition from issue #23.
  final String agentId;

  /// Human-readable display name (from agent `.md` frontmatter `name` field).
  final String agentName;

  /// Whether this agent is enabled in the current session.
  final bool isEnabled;

  /// Probability (0.0–1.0) that this agent will proactively speak
  /// after a user message. 0.0 = never, 1.0 = always.
  final double probability;

  /// Returns a copy with the given fields replaced.
  AgentParticipant copyWith({
    String? agentId,
    String? agentName,
    bool? isEnabled,
    double? probability,
  }) {
    return AgentParticipant(
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      isEnabled: isEnabled ?? this.isEnabled,
      probability: probability ?? this.probability,
    );
  }

  /// Serialises to a JSON-compatible map.
  Map<String, Object?> toMap() => {
        'agent_id': agentId,
        'agent_name': agentName,
        'is_enabled': isEnabled,
        'probability': probability,
      };

  /// Deserialises from a JSON-compatible map.
  factory AgentParticipant.fromMap(Map<String, Object?> map) {
    return AgentParticipant(
      agentId: map['agent_id'] as String,
      agentName: map['agent_name'] as String,
      isEnabled: map['is_enabled'] as bool? ?? true,
      probability: (map['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentParticipant &&
          runtimeType == other.runtimeType &&
          agentId == other.agentId;

  @override
  int get hashCode => agentId.hashCode;
}

/// Immutable snapshot of all agent participants in a session.
///
/// Used by [SessionCoordinator] to manage which agents are "at the table"
/// and their individual probability settings.
@immutable
class SessionParticipants {
  const SessionParticipants({this.participants = const []});

  /// The list of agents participating in this session.
  final List<AgentParticipant> participants;

  /// Returns only enabled participants.
  List<AgentParticipant> get active =>
      participants.where((p) => p.isEnabled).toList(growable: false);

  /// Looks up a participant by [agentId], or returns `null`.
  AgentParticipant? findById(String agentId) {
    for (final p in participants) {
      if (p.agentId == agentId) return p;
    }
    return null;
  }

  /// Serialises to a JSON-compatible map.
  Map<String, Object?> toMap() => {
        'participants': participants.map((p) => p.toMap()).toList(),
      };

  /// Deserialises from a JSON-compatible map.
  factory SessionParticipants.fromMap(Map<String, Object?> map) {
    return SessionParticipants(
      participants: (map['participants'] as List<Object?>?)
              ?.map((e) => AgentParticipant.fromMap(e as Map<String, Object?>))
              .toList() ??
          [],
    );
  }
}

/// Contract for coordinating multiple agents within a single session.
///
/// Builds on top of issue #23's single-agent [AgentSession] by adding
/// multi-agent participation management. Implementations decide which
/// agents should speak based on their probability settings.
abstract interface class SessionCoordinator {
  /// The current participants configuration.
  SessionParticipants get participants;

  /// Adds an agent to the session with the given probability.
  void addParticipant(AgentParticipant participant);

  /// Removes an agent from the session.
  void removeParticipant(String agentId);

  /// Updates the probability for an existing participant.
  void updateProbability(String agentId, double probability);

  /// Enables or disables an agent without removing it.
  void setEnabled(String agentId, bool enabled);

  /// Determines which active agents should proactively speak
  /// after a user message, based on their probability settings.
  ///
  /// Returns a list of agent IDs that should speak.
  List<String> decideProactiveSpeakers();
}
