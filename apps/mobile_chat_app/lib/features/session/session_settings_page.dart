import 'package:flutter/material.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:design_system/design_system.dart';
import 'agent_participant_tile.dart';

/// Session settings page — lets the user configure which agents participate
/// in the current session and adjust their proactive-speaking probability.
///
/// Navigation: ChatScreen AppBar → Session Settings.
class SessionSettingsPage extends StatefulWidget {
  const SessionSettingsPage({
    super.key,
    required this.coordinator,
  });

  /// The coordinator that owns the session's participant list.
  final SessionCoordinator coordinator;

  @override
  State<SessionSettingsPage> createState() => _SessionSettingsPageState();
}

class _SessionSettingsPageState extends State<SessionSettingsPage> {
  /// Returns a mutable snapshot of current participants.
  List<AgentParticipant> get _participants =>
      widget.coordinator.participants.participants.toList();

  void _toggle(String agentId, bool enabled) {
    widget.coordinator.setEnabled(agentId, enabled);
    setState(() {});
  }

  void _setProbability(String agentId, double probability) {
    widget.coordinator.updateProbability(agentId, probability);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final participants = _participants;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Settings')),
      body: participants.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(BricksSpacing.xl),
                child: Text(
                  'No agents in this session.\nAdd agents to enable proactive participation.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(BricksSpacing.md),
              itemCount: participants.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = participants[index];
                return AgentParticipantTile(
                  participant: p,
                  onToggle: (enabled) => _toggle(p.agentId, enabled),
                  onProbabilityChanged: (value) =>
                      _setProbability(p.agentId, value),
                );
              },
            ),
    );
  }
}
