import 'dart:math';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';

/// Manages multi-agent participation within a session.
///
/// This is the **delta from issue #23**: issue #23 defines agent identities
/// and storage; this class adds probability-based participation management
/// on top of those identities without duplicating agent definition logic.
class ParticipantManager implements SessionCoordinator {
  ParticipantManager({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<AgentParticipant> _participants = [];

  @override
  SessionParticipants get participants =>
      SessionParticipants(participants: List.unmodifiable(_participants));

  @override
  void addParticipant(AgentParticipant participant) {
    // Prevent duplicates — agent identity comes from #23's definitions.
    if (_participants.any((p) => p.agentId == participant.agentId)) {
      throw ArgumentError(
        'Agent "${participant.agentId}" is already in the session.',
      );
    }
    _participants.add(participant);
  }

  @override
  void removeParticipant(String agentId) {
    _participants.removeWhere((p) => p.agentId == agentId);
  }

  @override
  void updateProbability(String agentId, double probability) {
    if (probability < 0.0 || probability > 1.0) {
      throw RangeError.range(probability, 0, 1, 'probability');
    }
    final index = _participants.indexWhere((p) => p.agentId == agentId);
    if (index == -1) {
      throw ArgumentError('Agent "$agentId" is not in the session.');
    }
    _participants[index] = _participants[index].copyWith(
      probability: probability,
    );
  }

  @override
  void setEnabled(String agentId, bool enabled) {
    final index = _participants.indexWhere((p) => p.agentId == agentId);
    if (index == -1) {
      throw ArgumentError('Agent "$agentId" is not in the session.');
    }
    _participants[index] = _participants[index].copyWith(isEnabled: enabled);
  }

  @override
  List<String> decideProactiveSpeakers() {
    final speakers = <String>[];
    for (final p in _participants) {
      if (!p.isEnabled) continue;
      if (p.probability <= 0.0) continue;
      if (p.probability >= 1.0 || _random.nextDouble() < p.probability) {
        speakers.add(p.agentId);
      }
    }
    return speakers;
  }
}
