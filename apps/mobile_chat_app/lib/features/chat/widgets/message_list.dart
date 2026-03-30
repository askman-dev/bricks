import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';
import '../chat_message.dart';

/// Displays the list of chat messages in timeline format.
class MessageList extends StatelessWidget {
  const MessageList({super.key, required this.messages});

  final List<ChatMessage> messages;

  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('Start a conversation to create something.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(BricksSpacing.md),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.role == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Show agent attribution chip above the bubble when present.
              if (!isUser && msg.agentName != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: BricksSpacing.xs,
                    bottom: BricksSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smart_toy_outlined, size: 14),
                      const SizedBox(width: BricksSpacing.xs),
                      Text(
                        msg.agentName!,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(bottom: BricksSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: BricksSpacing.md,
                  vertical: BricksSpacing.sm,
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(BricksRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.content,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (msg.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: BricksSpacing.xs),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isUser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Show timestamp below the bubble.
              Padding(
                padding: const EdgeInsets.only(
                  left: BricksSpacing.xs,
                  right: BricksSpacing.xs,
                  bottom: BricksSpacing.md,
                ),
                child: Text(
                  _formatTime(msg.timestamp),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
