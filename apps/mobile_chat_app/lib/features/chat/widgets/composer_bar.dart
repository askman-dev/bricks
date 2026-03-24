import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// The input composer bar at the bottom of the chat screen.
class ComposerBar extends StatefulWidget {
  const ComposerBar({
    super.key,
    this.onSend,
    this.onStop,
    this.isStreaming = false,
  });

  /// Called when the user submits a message. Null while a send is in progress.
  final void Function(String text)? onSend;

  /// Called when the user stops streaming output.
  final VoidCallback? onStop;

  /// Whether AI is currently streaming output.
  final bool isStreaming;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.onSend == null) return;
    widget.onSend!(text);
    _controller.clear();
  }

  void _handleVoiceInput() {
    // TODO(chat): Implement voice input (placeholder for future).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice input coming soon')),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
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
            // Voice input button.
            IconButton(
              onPressed: widget.isStreaming ? null : _handleVoiceInput,
              icon: const Icon(Icons.mic_outlined),
              tooltip: 'Voice input',
            ),
            const SizedBox(width: BricksSpacing.xs),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !isSending && !widget.isStreaming,
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
            // Send or Stop button.
            if (widget.isStreaming)
              RotationTransition(
                turns: _spinController,
                child: IconButton.filled(
                  onPressed: widget.onStop,
                  icon: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onPrimary,
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.stop, size: 16),
                  ),
                  tooltip: 'Stop',
                ),
              )
            else
              IconButton.filled(
                onPressed: isSending ? null : _submit,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                tooltip: 'Send',
              ),
          ],
        ),
      ),
    );
  }
}
