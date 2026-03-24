import 'package:flutter/material.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:design_system/design_system.dart';

/// Dropdown selector for switching between agents.
///
/// Displays the current agent name and allows the user to select a different
/// agent from the list of session participants.
class AgentSelector extends StatelessWidget {
  const AgentSelector({
    super.key,
    required this.selectedAgentId,
    required this.participants,
    required this.onAgentSelected,
  });

  /// The ID of the currently selected agent.
  final String? selectedAgentId;

  /// The list of agents available in the session.
  final List<AgentParticipant> participants;

  /// Called when the user selects a different agent.
  final void Function(String agentId) onAgentSelected;

  @override
  Widget build(BuildContext context) {
    final selectedAgent = selectedAgentId != null
        ? participants.firstWhere(
            (p) => p.agentId == selectedAgentId,
            orElse: () => participants.isNotEmpty
                ? participants.first
                : const AgentParticipant(
                    agentId: 'none',
                    agentName: 'No Agent',
                  ),
          )
        : (participants.isNotEmpty
            ? participants.first
            : const AgentParticipant(
                agentId: 'none',
                agentName: 'No Agent',
              ));

    if (participants.isEmpty) {
      return Text(
        'No Agent',
        style: Theme.of(context).textTheme.titleMedium,
      );
    }

    return DropdownButton<String>(
      value: selectedAgent.agentId,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.arrow_drop_down),
      style: Theme.of(context).textTheme.titleMedium,
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: participants.map((participant) {
        return DropdownMenuItem<String>(
          value: participant.agentId,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_toy_outlined, size: 18),
              const SizedBox(width: BricksSpacing.xs),
              Text(participant.agentName),
            ],
          ),
        );
      }).toList(),
      onChanged: (String? newAgentId) {
        if (newAgentId != null && newAgentId != selectedAgent.agentId) {
          onAgentSelected(newAgentId);
        }
      },
    );
  }
}
