import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// The input composer bar at the bottom of the chat screen.
class ComposerBar extends StatefulWidget {
  const ComposerBar({super.key, this.onSend});

  /// Called when the user submits a message. Null while a send is in progress.
  final void Function(String text)? onSend;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.onSend == null) return;
    widget.onSend!(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSending = widget.onSend == null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BricksSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !isSending,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Ask Bricks to create something…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BricksRadius.lg),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: BricksSpacing.md,
                    vertical: BricksSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: BricksSpacing.sm),
            IconButton.filled(
              onPressed: isSending ? null : _submit,
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
