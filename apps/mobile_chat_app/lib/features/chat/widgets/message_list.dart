import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';
import '../chat_message.dart';

/// Displays the list of chat messages in timeline format.
class MessageList extends StatefulWidget {
  const MessageList({super.key, required this.messages});

  final List<ChatMessage> messages;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAutoScroll(oldWidget.messages, widget.messages)) {
      _scrollToBottom();
    }
  }

  bool _shouldAutoScroll(
      List<ChatMessage> previous, List<ChatMessage> current) {
    if (previous.length != current.length) {
      return true;
    }
    return _lastMessageSignature(previous) != _lastMessageSignature(current);
  }

  String? _lastMessageSignature(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    final last = messages.last;
    return [
      last.role,
      last.content,
      last.agentName ?? '',
      last.timestamp.microsecondsSinceEpoch.toString(),
      last.threadId ?? '',
      last.taskId ?? '',
      last.taskState?.name ?? '',
      last.isStreaming ? '1' : '0',
      last.isRecovered ? '1' : '0',
      last.arbitrationMode ? '1' : '0',
      last.resolvedBotId ?? '',
      last.fallbackToDefaultBot ? '1' : '0',
    ].join('|');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  String _taskLabel(ChatTaskState state) {
    switch (state) {
      case ChatTaskState.accepted:
        return 'accepted';
      case ChatTaskState.dispatched:
        return 'dispatched';
      case ChatTaskState.completed:
        return 'completed';
      case ChatTaskState.failed:
        return 'failed';
      case ChatTaskState.cancelled:
        return 'cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) {
      return const Center(
        child: SelectableText('Start a conversation to create something.'),
      );
    }

    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
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
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
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
                      if (msg.taskState != null || msg.taskId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: BricksSpacing.xs),
                          child: Text(
                            [
                              if (msg.taskState != null)
                                'task:${_taskLabel(msg.taskState!)}',
                              if (msg.taskId != null) 'id:${msg.taskId}',
                            ].join(' · '),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: isUser
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      if (msg.arbitrationMode && msg.resolvedBotId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: BricksSpacing.xs),
                          child: Text(
                            msg.fallbackToDefaultBot
                                ? 'fallback→${msg.resolvedBotId}'
                                : 'selected→${msg.resolvedBotId}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: isUser
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary,
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
                    [
                      _formatTime(msg.timestamp),
                      if (msg.threadId != null) 'thread:${msg.threadId}',
                      if (msg.isRecovered) 'Recovered',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
