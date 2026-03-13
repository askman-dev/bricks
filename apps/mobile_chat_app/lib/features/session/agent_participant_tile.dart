import 'package:flutter/material.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:design_system/design_system.dart';

/// A tile representing a single [AgentParticipant] in the session settings list.
///
/// Displays the agent name, an enable/disable checkbox, and a probability
/// slider (0–100%). Changes are reported back to the caller immediately
/// via [onToggle] and [onProbabilityChanged].
class AgentParticipantTile extends StatelessWidget {
  const AgentParticipantTile({
    super.key,
    required this.participant,
    required this.onToggle,
    required this.onProbabilityChanged,
  });

  final AgentParticipant participant;

  /// Called when the enabled checkbox changes.
  final void Function(bool enabled) onToggle;

  /// Called when the slider is moved; [value] is in the range 0.0–1.0.
  final void Function(double value) onProbabilityChanged;

  @override
  Widget build(BuildContext context) {
    final pct = (participant.probability * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BricksSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: participant.isEnabled,
                onChanged: (v) => onToggle(v ?? false),
              ),
              const SizedBox(width: BricksSpacing.xs),
              Expanded(
                child: Text(
                  participant.agentName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: participant.isEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          Slider(
            value: participant.probability,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '$pct%',
            onChanged: participant.isEnabled ? onProbabilityChanged : null,
          ),
        ],
      ),
    );
  }
}
