import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';
import '../chat_message.dart';

// Extra bottom padding as a fraction of screen height, so an incoming
// assistant reply is visible when the list is anchored on the latest user
// message. ~35 % of screen height works well across common phone sizes.
const double _kBottomPaddingRatio = 0.35;

/// Displays the list of chat messages in timeline format.
class MessageList extends StatefulWidget {
  const MessageList({super.key, required this.messages});

  final List<ChatMessage> messages;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  // A single key attached only to the focused (latest user) item so that
  // Scrollable.ensureVisible can locate it without creating a GlobalKey for
  // every list row.
  final GlobalKey _focusedItemKey = GlobalKey();
  int _focusedIndex = -1;

  // Persist the previous snapshot in state so comparisons work correctly even
  // when the same List instance is mutated in place (e.g. ChatScreen passes
  // _messages directly and mutates it via ..clear()..addAll / add / [i]=).
  int _prevLength = 0;
  _LastMessageKey? _prevLastKey;

  @override
  void initState() {
    super.initState();
    _focusedIndex = _focusedMessageIndex();
    _saveSnapshot();
    _scrollToFocusedUserMessage();
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final messages = widget.messages;
    final newLength = messages.length;
    final newKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.last);
    final wasStreamingTail = _prevLastKey?.isStreaming ?? false;
    final isStreamingTail = newKey?.isStreaming ?? false;
    // Use a stable identity that works even when messageId is null (e.g. older
    // persisted data or server payloads that haven't been assigned an ID yet).
    // Falls back to a composite of timestamp + role so that a streaming
    // assistant turn without a messageId is still recognised as "the same tail".
    final sameTailIdentity = _prevLastKey != null &&
        newKey != null &&
        _prevLastKey!.stableId == newKey.stableId;
    final streamingProgressOnly = newLength == _prevLength &&
        wasStreamingTail &&
        isStreamingTail &&
        sameTailIdentity;
    if (newLength != _prevLength || newKey != _prevLastKey) {
      _prevLength = newLength;
      _prevLastKey = newKey;
      if (!streamingProgressOnly) {
        _focusedIndex = _focusedMessageIndex();
        _scrollToFocusedUserMessage();
      }
    }
  }

  void _saveSnapshot() {
    final messages = widget.messages;
    _prevLength = messages.length;
    _prevLastKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.last);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _focusedMessageIndex() {
    for (var i = widget.messages.length - 1; i >= 0; i--) {
      if (widget.messages[i].role == 'user') return i;
    }
    return widget.messages.isEmpty ? -1 : widget.messages.length - 1;
  }

  void _scrollToFocusedUserMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (widget.messages.isEmpty) return;
      if (_focusedIndex < 0) return;

      // First jump to bottom to ensure trailing children are laid out, then
      // pin the focused message as the first visible item.
      final position = _scrollController.position;
      _scrollController.jumpTo(position.maxScrollExtent);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final targetContext = _focusedItemKey.currentContext;
        if (targetContext == null) return;
        Scrollable.ensureVisible(
          targetContext,
          duration: Duration.zero,
          alignment: 0,
        );
      });
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
        padding: EdgeInsets.fromLTRB(
          BricksSpacing.md,
          BricksSpacing.md,
          BricksSpacing.md,
          BricksSpacing.md +
              MediaQuery.of(context).size.height * _kBottomPaddingRatio,
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          final isUser = msg.role == 'user';
          // Attach the focused-item key only to the target row so that
          // _scrollToFocusedUserMessage can call Scrollable.ensureVisible
          // without maintaining a GlobalKey for every list item.
          final itemKey = index == _focusedIndex ? _focusedItemKey : null;
          return Align(
            key: itemKey,
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
                  key: ValueKey<String>(
                    'message-${msg.messageId ?? '${msg.timestamp}-$index'}',
                  ),
                  margin: const EdgeInsets.only(bottom: BricksSpacing.xs),
                  padding: isUser
                      ? const EdgeInsets.symmetric(
                          horizontal: BricksSpacing.md,
                          vertical: BricksSpacing.sm,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: BricksSpacing.xs,
                          vertical: BricksSpacing.xs,
                        ),
                  width: isUser ? null : double.infinity,
                  constraints: isUser
                      ? BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        )
                      : null,
                  decoration: isUser
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(BricksRadius.md),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUser)
                        _MessageExpandToggle(
                          key: ValueKey<String>(
                            'expand-toggle-${msg.messageId ?? '${msg.timestamp}-$index'}',
                          ),
                          text: msg.content,
                          textColor: Theme.of(context).colorScheme.onPrimary,
                        )
                      else
                        _AssistantMarkdownText(
                          text: msg.content,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          textStyle: Theme.of(context).textTheme.bodyMedium,
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

class _AssistantMarkdownText extends StatelessWidget {
  const _AssistantMarkdownText({
    required this.text,
    required this.textColor,
    required this.textStyle,
  });

  final String text;
  final Color textColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final baseStyle = (textStyle ?? const TextStyle()).copyWith(
      color: textColor,
    );
    final lines = text.split('\n');
    if (lines.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final block = _MarkdownBlock.tryParse(line);
        final lineStyle = block.type == _MarkdownBlockType.heading
            ? baseStyle.copyWith(fontWeight: FontWeight.w700)
            : baseStyle;
        final inlineSpans = _parseInlineMarkdown(
          block.text,
          baseStyle: lineStyle,
          headingLike: false,
        );
        if (block.type == _MarkdownBlockType.unorderedList ||
            block.type == _MarkdownBlockType.orderedList) {
          return Padding(
            padding: const EdgeInsets.only(left: BricksSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.marker,
                  style: lineStyle,
                ),
                const SizedBox(width: BricksSpacing.xs),
                Expanded(child: Text.rich(TextSpan(children: inlineSpans))),
              ],
            ),
          );
        }

        return Text.rich(TextSpan(children: inlineSpans));
      }).toList(growable: false),
    );
  }
}

enum _MarkdownBlockType { paragraph, heading, unorderedList, orderedList }

class _MarkdownBlock {
  const _MarkdownBlock({
    required this.type,
    required this.text,
    this.marker = '',
  });

  final _MarkdownBlockType type;
  final String text;
  final String marker;

  static final RegExp _headingPattern = RegExp(r'^\s{0,3}(#{1,6})\s+(.*)$');
  static final RegExp _unorderedListPattern = RegExp(r'^\s*([-*+])\s+(.*)$');
  static final RegExp _orderedListPattern = RegExp(r'^\s*(\d+)\.\s+(.*)$');

  static _MarkdownBlock tryParse(String line) {
    final headingMatch = _headingPattern.firstMatch(line);
    if (headingMatch != null) {
      return _MarkdownBlock(
        type: _MarkdownBlockType.heading,
        text: headingMatch.group(2) ?? '',
      );
    }

    final unorderedMatch = _unorderedListPattern.firstMatch(line);
    if (unorderedMatch != null) {
      return _MarkdownBlock(
        type: _MarkdownBlockType.unorderedList,
        marker: unorderedMatch.group(1) ?? '•',
        text: unorderedMatch.group(2) ?? '',
      );
    }

    final orderedMatch = _orderedListPattern.firstMatch(line);
    if (orderedMatch != null) {
      return _MarkdownBlock(
        type: _MarkdownBlockType.orderedList,
        marker: '${orderedMatch.group(1)}.',
        text: orderedMatch.group(2) ?? '',
      );
    }

    return _MarkdownBlock(type: _MarkdownBlockType.paragraph, text: line);
  }
}

List<InlineSpan> _parseInlineMarkdown(
  String source, {
  required TextStyle baseStyle,
  required bool headingLike,
}) {
  if (source.isEmpty) {
    return <InlineSpan>[
      TextSpan(text: '', style: _styleFor(baseStyle, false, false, headingLike))
    ];
  }

  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  var bold = false;
  var italic = false;
  var i = 0;

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(
      TextSpan(
        text: buffer.toString(),
        style: _styleFor(baseStyle, bold, italic, headingLike),
      ),
    );
    buffer.clear();
  }

  while (i < source.length) {
    if (i + 1 < source.length) {
      final pair = source.substring(i, i + 2);
      if (pair == '**' || pair == '__') {
        flush();
        bold = !bold;
        i += 2;
        continue;
      }
    }
    final char = source[i];
    if (char == '*' || char == '_') {
      flush();
      italic = !italic;
      i++;
      continue;
    }
    buffer.write(char);
    i++;
  }

  flush();
  return spans;
}

TextStyle _styleFor(
  TextStyle baseStyle,
  bool isBold,
  bool isItalic,
  bool headingLike,
) {
  return baseStyle.copyWith(
    fontWeight:
        (headingLike || isBold) ? FontWeight.w700 : baseStyle.fontWeight,
    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
  );
}

class _MessageExpandToggle extends StatefulWidget {
  const _MessageExpandToggle({
    super.key,
    required this.text,
    required this.textColor,
  });

  final String text;
  final Color textColor;

  @override
  State<_MessageExpandToggle> createState() => _MessageExpandToggleState();
}

class _MessageExpandToggleState extends State<_MessageExpandToggle> {
  bool _expanded = false;
  bool _overflowing = false;

  @override
  void didUpdateWidget(covariant _MessageExpandToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _expanded && !_overflowing) {
      _expanded = false;
    }
  }

  void _updateOverflow(bool next) {
    if (_overflowing == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _overflowing = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: widget.textColor,
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          textDirection: Directionality.of(context),
          maxLines: 3,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);
        _updateOverflow(painter.didExceedMaxLines);

        final content = Text(
          widget.text,
          style: textStyle,
          maxLines: _expanded ? null : 3,
          overflow: TextOverflow.ellipsis,
        );
        if (!_overflowing) return content;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 28),
              child: content,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                splashRadius: 16,
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: widget.textColor,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                tooltip: _expanded ? 'Collapse' : 'Expand',
              ),
            ),
          ],
        );
      },
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

  /// A stable identifier for this tail message that works even when
  /// [messageId] is null (e.g. older persisted data or in-flight assistant
  /// turns that haven't received a server-assigned ID yet). Falls back to a
  /// composite of timestamp and role, which is sufficient to detect that the
  /// same streaming turn is still in progress.
  String get stableId => messageId ?? '$timestampMicros:$role';

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
