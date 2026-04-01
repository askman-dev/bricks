import 'dart:async';

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
    required this.currentModel,
    required this.availableModels,
    this.onModelSelected,
  });

  /// The coordinator that owns the session's participant list.
  final SessionCoordinator coordinator;
  final String currentModel;
  final List<String> availableModels;
  final Future<void> Function(String modelId)? onModelSelected;

  @override
  State<SessionSettingsPage> createState() => _SessionSettingsPageState();
}

class _SessionSettingsPageState extends State<SessionSettingsPage> {
  late String _selectedModelId;
  bool _savingModel = false;

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.currentModel;
  }

  /// Returns a mutable snapshot of current participants.
  List<AgentParticipant> get _participants =>
      widget.coordinator.participants.participants.toList();

  Future<void> _selectModel(String modelId) async {
    if (_savingModel || modelId == _selectedModelId) return;
    setState(() {
      _selectedModelId = modelId;
      _savingModel = true;
    });
    try {
      await widget.onModelSelected?.call(modelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model switched to $modelId')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _savingModel = false);
    }
  }

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
      body: ListView(
        padding: const EdgeInsets.all(BricksSpacing.md),
        children: [
          Text(
            'Model Selection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: BricksSpacing.xs),
          RadioGroup<String>(
            groupValue: _selectedModelId,
            onChanged: (value) {
              if (_savingModel || value == null) return;
              unawaited(_selectModel(value));
            },
            child: Column(
              children: widget.availableModels
                  .map(
                    (modelId) => RadioListTile<String>(
                      value: modelId,
                      title: Text(modelId),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_savingModel)
            const Padding(
              padding: EdgeInsets.only(bottom: BricksSpacing.md),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: BricksSpacing.sm),
          Text(
            'Agent Participation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: BricksSpacing.xs),
          if (participants.isEmpty)
            Padding(
              padding: const EdgeInsets.all(BricksSpacing.xl),
              child: Text(
                'No agents in this session.\nAdd agents to enable proactive participation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            )
          else
            ...List.generate(participants.length, (index) {
              final p = participants[index];
              return Column(
                children: [
                  AgentParticipantTile(
                    participant: p,
                    onToggle: (enabled) => _toggle(p.agentId, enabled),
                    onProbabilityChanged: (value) =>
                        _setProbability(p.agentId, value),
                  ),
                  if (index < participants.length - 1) const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }
}
