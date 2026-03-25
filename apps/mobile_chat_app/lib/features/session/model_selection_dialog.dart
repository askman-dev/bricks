import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// Hard-coded list of Gemini 3.x model IDs available for selection.
const List<String> kGeminiModels = [
  'gemini-3.1-pro-preview',
  'gemini-3.1-flash-lite-preview',
  'gemini-3-flash-preview',
];

/// Dialog for selecting the AI model for the current session.
///
/// Displays a radio-button list of hard-coded Gemini 3.x model IDs.
/// Returns the selected model ID when the user confirms, or [null] if
/// the dialog is dismissed without a selection.
class ModelSelectionDialog extends StatefulWidget {
  const ModelSelectionDialog({
    super.key,
    required this.currentModel,
  });

  /// The model ID that is currently active for the session.
  final String currentModel;

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentModel;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Model'),
      contentPadding: const EdgeInsets.symmetric(
        vertical: BricksSpacing.sm,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: kGeminiModels.map((modelId) {
          return RadioListTile<String>(
            title: Text(modelId),
            value: modelId,
            groupValue: _selected,
            onChanged: (value) {
              if (value != null) setState(() => _selected = value);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
