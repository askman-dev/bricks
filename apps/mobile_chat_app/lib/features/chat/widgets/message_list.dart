import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import '../chat_message.dart';

/// Displays the list of chat messages.
class MessageList extends StatelessWidget {
  const MessageList({super.key, required this.messages});

  final List<ChatMessage> messages;

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
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: BricksSpacing.xs),
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
            child: Text(
              msg.content,
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}
