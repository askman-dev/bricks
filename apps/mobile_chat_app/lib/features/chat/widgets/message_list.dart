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

  // Persist the previous snapshot in state so comparisons work correctly even
  // when the same List instance is mutated in place (e.g. ChatScreen passes
  // _messages directly and mutates it via ..clear()..addAll / add / [i]=).
  int _prevLength = 0;
  _LastMessageKey? _prevLastKey;

  @override
  void initState() {
    super.initState();
    _saveSnapshot();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final messages = widget.messages;
    final newLength = messages.length;
    final newKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.last);
    if (newLength != _prevLength || newKey != _prevLastKey) {
      _prevLength = newLength;
      _prevLastKey = newKey;
      // During active streaming only snap to bottom when the user is already
      // near it; otherwise always scroll so history loads land at the bottom.
      final isStreamingUpdate =
          messages.isNotEmpty && messages.last.isStreaming;
      if (!isStreamingUpdate || _isNearBottom()) {
        _scrollToBottom();
      }
    }
  }

  void _saveSnapshot() {
    final messages = widget.messages;
    _prevLength = messages.length;
    _prevLastKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.last);
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 100.0;
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

/// Immutable snapshot of the fields that identify a specific last message.
///
/// Using proper field equality (instead of a delimiter-joined string) avoids
/// false matches when field values happen to contain the delimiter character.
class _LastMessageKey {
  const _LastMessageKey({
    required this.messageId,
    required this.role,
    required this.content,
    required this.timestampMicros,
    required this.isStreaming,
    required this.taskId,
    required this.taskState,
    required this.threadId,
    required this.resolvedBotId,
    required this.arbitrationMode,
    required this.fallbackToDefaultBot,
    required this.agentName,
    required this.isRecovered,
  });

  factory _LastMessageKey.from(ChatMessage msg) => _LastMessageKey(
        messageId: msg.messageId,
        role: msg.role,
        content: msg.content,
        timestampMicros: msg.timestamp.microsecondsSinceEpoch,
        isStreaming: msg.isStreaming,
        taskId: msg.taskId,
        taskState: msg.taskState,
        threadId: msg.threadId,
        resolvedBotId: msg.resolvedBotId,
        arbitrationMode: msg.arbitrationMode,
        fallbackToDefaultBot: msg.fallbackToDefaultBot,
        agentName: msg.agentName,
        isRecovered: msg.isRecovered,
      );

  final String? messageId;
  final String role;
  final String content;
  final int timestampMicros;
  final bool isStreaming;
  final String? taskId;
  final ChatTaskState? taskState;
  final String? threadId;
  final String? resolvedBotId;
  final bool arbitrationMode;
  final bool fallbackToDefaultBot;
  final String? agentName;
  final bool isRecovered;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LastMessageKey &&
          messageId == other.messageId &&
          role == other.role &&
          content == other.content &&
          timestampMicros == other.timestampMicros &&
          isStreaming == other.isStreaming &&
          taskId == other.taskId &&
          taskState == other.taskState &&
          threadId == other.threadId &&
          resolvedBotId == other.resolvedBotId &&
          arbitrationMode == other.arbitrationMode &&
          fallbackToDefaultBot == other.fallbackToDefaultBot &&
          agentName == other.agentName &&
          isRecovered == other.isRecovered;

  @override
  int get hashCode => Object.hashAll([
        messageId,
        role,
        content,
        timestampMicros,
        isStreaming,
        taskId,
        taskState,
        threadId,
        resolvedBotId,
        arbitrationMode,
        fallbackToDefaultBot,
        agentName,
        isRecovered,
      ]);
}
