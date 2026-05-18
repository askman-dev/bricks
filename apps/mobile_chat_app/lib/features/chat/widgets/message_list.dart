import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';
import '../chat_message.dart';
import '../text_highlight_api_service.dart';

// Extra bottom padding as a fraction of screen height, so the latest user
// message can be anchored near the top while leaving room for the assistant
// reply to stream below it.
const double _kBottomPaddingRatio = 0.75;

/// A span of highlighted text within a message, used for rendering.
class HighlightSpan {
  const HighlightSpan({
    required this.highlightId,
    required this.selectedText,
    required this.color,
    this.startOffset,
    this.endOffset,
  });

  final String highlightId;
  final String selectedText;
  final int? startOffset;
  final int? endOffset;
  final String color;

  static HighlightSpan fromHighlight(TextHighlight h) => HighlightSpan(
        highlightId: h.id,
        selectedText: h.selectedText,
        startOffset: h.startOffset,
        endOffset: h.endOffset,
        color: h.color,
      );
}

/// Displays the list of chat messages in timeline format.
class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.messages,
    this.highlights = const {},
    this.onHighlight,
    this.onDeleteHighlight,
  });

  final List<ChatMessage> messages;

  /// Map from messageId to the list of highlights applied to that message.
  final Map<String, List<HighlightSpan>> highlights;

  /// Called when the user selects text and taps the Highlight context menu
  /// action. Provides the messageId, selected text, and approximate offsets.
  final void Function(
    String messageId,
    String selectedText,
    int? startOffset,
    int? endOffset,
  )? onHighlight;

  /// Called when the user taps 删除划线 in the floating highlight menu.
  final void Function(String highlightId)? onDeleteHighlight;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  static const double _kJumpButtonShowScreens = 2;
  bool _showJumpToLatestButton = false;
  double _listBottomPadding = 0;

  // A single key attached only to the focused (latest user) item so that
  // Scrollable.ensureVisible can locate it without creating a GlobalKey for
  // every list row.
  final GlobalKey _focusedItemKey = GlobalKey();
  final GlobalKey _scrollViewKey = GlobalKey();
  int _focusedIndex = -1;

  // Persist the previous snapshot in state so comparisons work correctly even
  // when the same List instance is mutated in place (e.g. ChatScreen passes
  // _messages directly and mutates it via ..clear()..addAll / add / [i]=).
  int _prevLength = 0;
  _LastMessageKey? _prevFirstKey;
  _LastMessageKey? _prevLastKey;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollChanged);
    _focusedIndex = _focusedUserMessageIndex();
    _saveSnapshot();
    _scrollToInitialAnchor();
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final messages = widget.messages;
    final previousLength = _prevLength;
    final previousFirstKey = _prevFirstKey;
    final previousLastKey = _prevLastKey;
    final newLength = messages.length;
    final newFirstKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.first);
    final newKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.last);
    if (newLength != previousLength ||
        newFirstKey != previousFirstKey ||
        newKey != previousLastKey) {
      final appendedMessage = newLength > previousLength && messages.isNotEmpty
          ? messages.last
          : null;
      final becameNonEmpty = previousLength == 0 && newLength > 0;
      final switchedConversation =
          previousLength > 0 && newFirstKey != previousFirstKey;
      final shouldAnchorAppendedUser = appendedMessage?.role == 'user' &&
          (previousLength == 0 || _isLatestResponseEndVisible());
      _prevLength = newLength;
      _prevFirstKey = newFirstKey;
      _prevLastKey = newKey;

      // Auto-focus on initial population, conversation switches, and when a
      // new user message is sent.
      // During assistant streaming/progress updates, keep the current viewport
      // stable so the app never fights user scrolling.
      if (becameNonEmpty || switchedConversation || shouldAnchorAppendedUser) {
        _focusedIndex = _focusedUserMessageIndex();
        _scrollToInitialAnchor();
      }
    }
  }

  void _saveSnapshot() {
    final messages = widget.messages;
    _prevLength = messages.length;
    _prevFirstKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.first);
    _prevLastKey =
        messages.isEmpty ? null : _LastMessageKey.from(messages.last);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceToLatestAnchor = _distanceToLatestContentAnchor(position);
    final shouldShow = distanceToLatestAnchor >
        position.viewportDimension * _kJumpButtonShowScreens;
    if (shouldShow != _showJumpToLatestButton) {
      setState(() {
        _showJumpToLatestButton = shouldShow;
      });
    }
  }

  bool _hasUserMessage() =>
      widget.messages.any((message) => message.role == 'user');

  bool _isLatestResponseEndVisible() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    final distanceToLatestAnchor = _distanceToLatestContentAnchor(position);
    return distanceToLatestAnchor <= 24;
  }

  int _focusedUserMessageIndex() {
    for (var i = widget.messages.length - 1; i >= 0; i--) {
      if (widget.messages[i].role == 'user') return i;
    }
    return -1;
  }

  void _scrollToInitialAnchor() {
    if (_focusedIndex >= 0) {
      _scrollToFocusedUserMessage();
    } else {
      _scrollToHistoryEnd();
    }
  }

  double _userTailVisibleHeight(BuildContext context, double itemHeight) {
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final fontSize = textStyle?.fontSize ?? 16;
    final lineHeight = (textStyle?.height ?? 1.35) * fontSize;
    // Keep roughly the final two text lines plus bubble padding/metadata.
    return (lineHeight * 2 + BricksSpacing.sm * 2 + BricksSpacing.xs + 20)
        .clamp(56.0, itemHeight)
        .toDouble();
  }

  void _scrollToFocusedUserMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (widget.messages.isEmpty) return;
      if (_focusedIndex < 0) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final targetContext = _focusedItemKey.currentContext;
        if (targetContext == null) return;
        final scrollContext = _scrollViewKey.currentContext;
        final targetRender = targetContext.findRenderObject();
        final scrollRender = scrollContext?.findRenderObject();
        if (targetRender is! RenderBox || scrollRender is! RenderBox) {
          return;
        }
        final targetTop =
            targetRender.localToGlobal(Offset.zero, ancestor: scrollRender).dy;
        final targetHeight = targetRender.size.height;
        final visibleTailHeight =
            _userTailVisibleHeight(targetContext, targetHeight);
        final overflowAdjustment =
            (targetHeight - visibleTailHeight).clamp(0.0, double.infinity);
        final targetOffset =
            (_scrollController.position.pixels + targetTop + overflowAdjustment)
                .clamp(
                  _scrollController.position.minScrollExtent,
                  _scrollController.position.maxScrollExtent,
                )
                .toDouble();
        _scrollController.jumpTo(targetOffset);
        _handleScrollChanged();
      });
    });
  }

  void _scrollToHistoryEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _handleScrollChanged();
    });
  }

  double _latestContentAnchorOffset(ScrollPosition position) {
    return (position.maxScrollExtent - _listBottomPadding)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  double _distanceToLatestContentAnchor(ScrollPosition position) {
    final anchorOffset = _latestContentAnchorOffset(position);
    return (anchorOffset - position.pixels)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  void _scrollToLatestMessage() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final targetOffset = _latestContentAnchorOffset(position);
    final distance = (targetOffset - position.pixels).abs();
    final durationMs = (180 + distance * 0.18).clamp(220, 560).round();
    _scrollController.animateTo(
      targetOffset,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp.toLocal());
  }

  String _messageMetaLine(ChatMessage message) {
    return [
      _formatTime(message.timestamp),
      if (message.threadId != null) 'thread:${message.threadId}',
      if (message.isRecovered) 'Recovered',
    ].join(' · ');
  }

  bool _isAssistantDispatchPlaceholder(ChatMessage message) {
    if (message.role != 'assistant') return false;
    if (message.content.trim().isNotEmpty) return false;
    // Agent-loop status messages (tool_call_start etc.) have their own rendering.
    if (message.agentLoopPhase != null) return false;
    if (message.taskState != ChatTaskState.dispatched &&
        message.taskState != ChatTaskState.accepted) {
      return false;
    }
    return message.agentName != null || message.model != null;
  }

  _UserDeliveryStatus? _deliveryIndicatorForUserMessage(
    ChatMessage message,
    List<ChatMessage> allMessages,
  ) {
    final persisted = message.taskState == ChatTaskState.accepted ||
        message.taskState == ChatTaskState.dispatched ||
        message.taskState == ChatTaskState.completed;
    if (!persisted) {
      return null;
    }

    final source = message.source;
    final openclawBySource = source == 'backend.respond.openclaw';
    final genericRemoteBySource = source != null &&
        source.startsWith('backend.respond.') &&
        source != 'backend.respond.openclaw';
    final openclawByResolvedBot = (source == null || source.isEmpty) &&
        message.resolvedBotId == 'openclaw';
    final isOpenclaw = openclawBySource || openclawByResolvedBot;
    final isGenericRemote = genericRemoteBySource;
    var hasReplyStarted = false;
    var hasReplyCompleted = false;
    for (final candidate in allMessages) {
      if (candidate.role != 'assistant' ||
          candidate.taskId == null ||
          candidate.taskId != message.taskId) {
        continue;
      }
      hasReplyStarted = true;
      if (candidate.taskState == ChatTaskState.completed ||
          candidate.content.isNotEmpty) {
        hasReplyCompleted = true;
      }
      break;
    }

    final secondIcon = hasReplyStarted
        ? (isOpenclaw
            ? _DeliveryIconState.openclaw()
            : _DeliveryIconState.check(isCompleted: hasReplyCompleted))
        : null;
    if (!isOpenclaw && !isGenericRemote && !hasReplyStarted) {
      return const _UserDeliveryStatus(first: _DeliveryIconState.check());
    }
    return _UserDeliveryStatus(
      first: const _DeliveryIconState.check(),
      second: secondIcon,
    );
  }

  Future<void> _showUserMessageContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required ChatMessage message,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) => _UserMessageContextMenu(
        position: globalPosition,
        screenSize: overlay.size,
        message: message,
      ),
    );
    if (!context.mounted || result == null) return;
    switch (result) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.content));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制')));
        break;
      case 'branch':
      case 'resend':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('功能待开发')));
        break;
    }
  }

  // Builds a single message row for the given [index] in [widget.messages].
  // Extracted from build() so that the non-builder ListView can call it in a
  // simple for-loop while keeping the item rendering logic in one place.
  Widget _buildMessageItem(BuildContext context, int index) {
    final allMessages = widget.messages;
    final msg = allMessages[index];
    final isUser = msg.role == 'user';
    final isAssistantDispatchPlaceholder = _isAssistantDispatchPlaceholder(msg);
    final deliveryIndicator =
        isUser ? _deliveryIndicatorForUserMessage(msg, allMessages) : null;
    // Resolve chat-specific semantic colors from the ThemeExtension.
    // Falling back to the light defaults keeps plain MaterialApp tests
    // working without an explicit BricksTheme.
    final chatColors =
        Theme.of(context).extension<ChatColors>() ?? ChatColors.light;
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
          // Show agent attribution chip as soon as assistant identity is
          // known, including dispatch placeholders pushed by SSE before
          // any assistant text is available.
          if (!isUser && (msg.agentName != null || msg.model != null))
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
                    msg.agentName ?? msg.model ?? '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: chatColors.agentIdentity,
                        ),
                  ),
                  if (msg.nodeType?.trim().isNotEmpty == true) ...[
                    const SizedBox(width: BricksSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: chatColors.agentBadgeContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        msg.nodeType!.trim(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: chatColors.onAgentBadgeContainer,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (isAssistantDispatchPlaceholder)
            Padding(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        chatColors.agentAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: BricksSpacing.xs),
                  Text(
                    '处理中…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                left: BricksSpacing.xs,
                right: BricksSpacing.xs,
                bottom: BricksSpacing.xs,
              ),
            )
          else if (!isUser &&
              msg.agentLoopPhase != null &&
              msg.agentLoopPhase != 'tool_call')
            _AgentLoopStatusRow(
              phase: msg.agentLoopPhase!,
              toolName: msg.agentLoopTool,
              content: msg.content,
              chatColors: chatColors,
              taskState: msg.taskState,
            )
          else
            GestureDetector(
              onLongPressStart: isUser
                  ? (details) => _showUserMessageContextMenu(
                        context: context,
                        globalPosition: details.globalPosition,
                        message: msg,
                      )
                  : null,
              child: Container(
                key: ValueKey<String>(
                  'message-${msg.messageId ?? '${msg.timestamp}-$index'}',
                ),
                margin: isUser
                    ? const EdgeInsets.only(
                        bottom: BricksSpacing.md,
                      )
                    : const EdgeInsets.only(
                        bottom: BricksSpacing.xs,
                      ),
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
                        color: chatColors.messageUserBackground,
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
                        textColor: chatColors.onMessageUser,
                      )
                    else
                      _AssistantMessageSelectionArea(
                        message: msg,
                        highlights: msg.messageId != null
                            ? (widget.highlights[msg.messageId!] ?? const [])
                            : const [],
                        onHighlight: widget.onHighlight,
                        onDeleteHighlight: widget.onDeleteHighlight,
                        child: _AssistantMarkdownText(
                          text: msg.content,
                          textColor: chatColors.onMessageAssistant,
                          linkColor: chatColors.linkText,
                          codeBlockColor: chatColors.codeBlockBackground,
                          quoteBlockColor: chatColors.quoteBackground,
                          textStyle: Theme.of(context).textTheme.bodyLarge,
                          highlights: msg.messageId != null
                              ? (widget.highlights[msg.messageId!] ?? const [])
                              : const [],
                          onDeleteHighlight: widget.onDeleteHighlight,
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
                                  ? chatColors.onMessageUser
                                  : chatColors.agentAccent,
                            ),
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
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isUser
                                        ? chatColors.onMessageUser
                                        : chatColors.agentAccent,
                                  ),
                        ),
                      ),
                    if (isUser)
                      Padding(
                        padding: const EdgeInsets.only(top: BricksSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _messageMetaLine(msg),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: chatColors.onMessageUser
                                          .withValues(alpha: 0.68),
                                    ),
                              ),
                            ),
                            if (deliveryIndicator != null) ...[
                              const SizedBox(width: BricksSpacing.xs),
                              _UserMessageDeliveryStatus(
                                indicator: deliveryIndicator,
                                messageId: msg.messageId,
                                foregroundColor: chatColors.onMessageUser,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(
                left: BricksSpacing.xs,
                right: BricksSpacing.xs,
                bottom: BricksSpacing.md,
              ),
              child: Text(
                _messageMetaLine(msg),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: chatColors.metaText,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) {
      return const Center(
        child: SelectableText('Start a conversation to create something.'),
      );
    }

    _listBottomPadding = BricksSpacing.md +
        (_hasUserMessage()
            ? MediaQuery.sizeOf(context).height * _kBottomPaddingRatio
            : 0);

    // All messages in the initial load are bounded (≤ 20 items). Building
    // them eagerly with a non-builder ListView gives an accurate
    // maxScrollExtent from the very first frame, so _scrollToFocusedUserMessage
    // can call Scrollable.ensureVisible directly without any jumpTo/retry hack.
    return Stack(
      children: [
        SingleChildScrollView(
          key: _scrollViewKey,
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            BricksSpacing.md,
            BricksSpacing.md,
            BricksSpacing.md,
            _listBottomPadding,
          ),
          child: Column(
            children: [
              for (var i = 0; i < messages.length; i++)
                _buildMessageItem(context, i),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: BricksSpacing.md,
          child: IgnorePointer(
            ignoring: !_showJumpToLatestButton,
            child: AnimatedOpacity(
              opacity: _showJumpToLatestButton ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: Builder(
                  builder: (context) {
                    final chatColors =
                        Theme.of(context).extension<ChatColors>() ??
                            ChatColors.light;
                    return IconButton.filled(
                      onPressed: _scrollToLatestMessage,
                      tooltip: 'Jump to latest',
                      style: IconButton.styleFrom(
                        backgroundColor: chatColors.jumpToLatestBackground,
                        foregroundColor: chatColors.onJumpToLatest,
                      ),
                      icon: const Icon(Icons.arrow_downward),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserMessageDeliveryStatus extends StatelessWidget {
  const _UserMessageDeliveryStatus({
    required this.indicator,
    required this.messageId,
    this.foregroundColor,
  });

  final _UserDeliveryStatus indicator;
  final String? messageId;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey<String>('user-delivery-${messageId ?? 'unknown'}');
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DeliveryStatusIcon(
            icon: indicator.first, foregroundColor: foregroundColor),
        if (indicator.second != null) ...[
          const SizedBox(width: 2),
          _DeliveryStatusIcon(
              icon: indicator.second!, foregroundColor: foregroundColor),
        ],
      ],
    );
  }
}

enum _DeliveryIcon { openclaw, check }

class _DeliveryIconState {
  const _DeliveryIconState._({
    required this.icon,
    required this.isCompleted,
    required this.opacity,
  });

  const _DeliveryIconState.openclaw({bool isDispatched = true})
      : this._(
          icon: _DeliveryIcon.openclaw,
          isCompleted: false,
          opacity: isDispatched ? 0.75 : 0.45,
        );

  const _DeliveryIconState.check({bool isCompleted = false})
      : this._(
          icon: _DeliveryIcon.check,
          isCompleted: isCompleted,
          opacity: 1,
        );

  final _DeliveryIcon icon;
  final bool isCompleted;
  final double opacity;
}

class _UserDeliveryStatus {
  const _UserDeliveryStatus({required this.first, this.second});

  final _DeliveryIconState first;
  final _DeliveryIconState? second;
}

class _DeliveryStatusIcon extends StatelessWidget {
  const _DeliveryStatusIcon({required this.icon, this.foregroundColor});

  final _DeliveryIconState icon;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final statusLabel = icon.icon == _DeliveryIcon.openclaw
        ? 'OpenClaw reply started'
        : icon.isCompleted
            ? 'AI reply completed'
            : 'Persisted';
    if (icon.icon == _DeliveryIcon.openclaw) {
      return Semantics(
        label: statusLabel,
        child: Tooltip(
          message: statusLabel,
          child: Icon(
            Icons.hub_outlined,
            size: 14,
            color: (foregroundColor ?? Theme.of(context).colorScheme.outline)
                .withValues(alpha: icon.opacity),
          ),
        ),
      );
    }
    return Semantics(
      label: statusLabel,
      child: Tooltip(
        message: statusLabel,
        child: Icon(
          Icons.check,
          size: 14,
          color: foregroundColor != null
              ? foregroundColor!.withValues(alpha: icon.isCompleted ? 1.0 : 0.6)
              : icon.isCompleted
                  ? AppColors.success
                  : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _ResolvedAssistantSelection {
  const _ResolvedAssistantSelection({
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    this.matchingHighlightId,
  });

  final String selectedText;
  final int? startOffset;
  final int? endOffset;
  final String? matchingHighlightId;
}

class _AssistantMessageSelectionArea extends StatefulWidget {
  const _AssistantMessageSelectionArea({
    required this.message,
    required this.highlights,
    required this.child,
    this.onHighlight,
    this.onDeleteHighlight,
  });

  final ChatMessage message;
  final List<HighlightSpan> highlights;
  final Widget child;
  final void Function(
    String messageId,
    String selectedText,
    int? startOffset,
    int? endOffset,
  )? onHighlight;
  final void Function(String highlightId)? onDeleteHighlight;

  @override
  State<_AssistantMessageSelectionArea> createState() =>
      _AssistantMessageSelectionAreaState();
}

class _AssistantMessageSelectionAreaState
    extends State<_AssistantMessageSelectionArea> {
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (value) {
        _selectedText = value?.plainText ?? '';
      },
      contextMenuBuilder: (ctx, selectableRegionState) {
        final resolved = _resolveAssistantSelection(
          messageText: widget.message.content,
          selectedText: _selectedText,
          highlights: widget.highlights,
        );
        final extraItems = <ContextMenuButtonItem>[];
        final matchingHighlightId = resolved?.matchingHighlightId;
        if (matchingHighlightId != null && widget.onDeleteHighlight != null) {
          extraItems.add(
            ContextMenuButtonItem(
              label: '删除划线',
              onPressed: () {
                ContextMenuController.removeAny();
                widget.onDeleteHighlight!(matchingHighlightId);
              },
            ),
          );
        } else if (resolved != null &&
            widget.onHighlight != null &&
            widget.message.messageId != null) {
          extraItems.add(
            ContextMenuButtonItem(
              label: '划线',
              onPressed: () {
                ContextMenuController.removeAny();
                widget.onHighlight!(
                  widget.message.messageId!,
                  resolved.selectedText,
                  resolved.startOffset,
                  resolved.endOffset,
                );
              },
            ),
          );
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: [
            ...selectableRegionState.contextMenuButtonItems,
            ...extraItems,
          ],
        );
      },
      child: widget.child,
    );
  }
}

_ResolvedAssistantSelection? _resolveAssistantSelection({
  required String messageText,
  required String selectedText,
  required List<HighlightSpan> highlights,
}) {
  final normalizedSelection =
      selectedText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalizedSelection.trim().isEmpty) return null;
  final mapping = _RenderedTextIndex.fromMarkdownMessage(messageText);
  final renderedStart = mapping.text.indexOf(normalizedSelection);
  int? startOffset;
  int? endOffset;
  if (renderedStart != -1) {
    startOffset = mapping.sourceOffsetAt(renderedStart);
    endOffset =
        mapping.sourceOffsetAfter(renderedStart + normalizedSelection.length);
  } else {
    final normalizedMessage =
        messageText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawStart = normalizedMessage.indexOf(normalizedSelection);
    if (rawStart != -1) {
      startOffset = rawStart;
      endOffset = rawStart + normalizedSelection.length;
    }
  }

  String? matchingHighlightId;
  for (final highlight in highlights) {
    if (_highlightMatchesSelection(
      highlight: highlight,
      selectedText: normalizedSelection,
      startOffset: startOffset,
      endOffset: endOffset,
    )) {
      matchingHighlightId = highlight.highlightId;
      break;
    }
  }

  return _ResolvedAssistantSelection(
    selectedText: normalizedSelection,
    startOffset: startOffset,
    endOffset: endOffset,
    matchingHighlightId: matchingHighlightId,
  );
}

bool _highlightMatchesSelection({
  required HighlightSpan highlight,
  required String selectedText,
  required int? startOffset,
  required int? endOffset,
}) {
  if (highlight.startOffset != null &&
      highlight.endOffset != null &&
      startOffset != null &&
      endOffset != null) {
    return highlight.startOffset == startOffset &&
        highlight.endOffset == endOffset;
  }
  return highlight.selectedText == selectedText;
}

/// Shows a floating popup menu when the user taps a highlighted span.
/// The menu offers Copy and 删除划线 (delete highlight) actions.
void _showHighlightTapMenu({
  required BuildContext context,
  required String highlightId,
  required String text,
  required Offset position,
  required void Function(String highlightId) onDeleteHighlight,
}) {
  final size = MediaQuery.of(context).size;
  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      size.width - position.dx,
      size.height - position.dy,
    ),
    items: const [
      PopupMenuItem<String>(value: 'copy', child: Text('复制')),
      PopupMenuItem<String>(value: 'delete', child: Text('删除划线')),
    ],
  ).then((value) {
    if (value == 'copy') {
      Clipboard.setData(ClipboardData(text: text));
    } else if (value == 'delete') {
      onDeleteHighlight(highlightId);
    }
  });
}

class _AssistantMarkdownText extends StatefulWidget {
  const _AssistantMarkdownText({
    required this.text,
    required this.textColor,
    required this.linkColor,
    required this.codeBlockColor,
    required this.quoteBlockColor,
    required this.textStyle,
    this.highlights = const [],
    this.onDeleteHighlight,
  });

  final String text;
  final Color textColor;
  final Color linkColor;
  final Color codeBlockColor;
  final Color quoteBlockColor;
  final TextStyle? textStyle;
  final List<HighlightSpan> highlights;

  /// Called when the user taps 删除划线 in the floating highlight popup.
  final void Function(String highlightId)? onDeleteHighlight;

  @override
  State<_AssistantMarkdownText> createState() => _AssistantMarkdownTextState();
}

class _AssistantMarkdownTextState extends State<_AssistantMarkdownText> {
  /// Gesture recognizers created during the last build. Disposed before each
  /// rebuild and on widget removal to prevent memory leaks.
  final List<GestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispose any recognizers from the previous build before allocating new ones.
    _disposeRecognizers();
    final text = widget.text;
    final textColor = widget.textColor;
    final textStyle = widget.textStyle;
    final linkColor = widget.linkColor;
    final codeBlockColor = widget.codeBlockColor;
    final quoteBlockColor = widget.quoteBlockColor;
    final highlights = widget.highlights;
    final onDeleteHighlight = widget.onDeleteHighlight;
    final baseStyle = (textStyle ?? const TextStyle()).copyWith(
      color: textColor,
    );
    if (text.isEmpty) {
      return Text(text, style: baseStyle);
    }
    // Normalize line endings so that line splitting is consistent.
    // \r\n → \n, lone \r → \n.
    final normalizedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalizedText.split('\n');
    final widgets = <Widget>[];
    var inCodeBlock = false;
    final codeLines = <_SourceLine>[];

    final highlightRanges = _highlightRangesForMessage(
      highlights: highlights,
      normalizedText: normalizedText,
    );

    List<InlineSpan> _applyHighlightsToSpans(
      List<_OffsetTextSpan> spans,
    ) {
      if (highlightRanges.isEmpty) {
        return spans.map((span) => span.span).toList();
      }
      return _splitOffsetSpansByHighlights(
        spans: spans,
        highlights: highlightRanges,
        baseStyle: baseStyle,
        context: context,
        onDeleteHighlight: onDeleteHighlight,
        recognizers: _recognizers,
      );
    }

    Widget _buildCodeBlock(List<_SourceLine> codeContent) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: BricksSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: BricksSpacing.sm,
            vertical: BricksSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: codeBlockColor,
            borderRadius: BorderRadius.circular(BricksRadius.sm),
          ),
          child: Text.rich(
            TextSpan(
              children: _applyHighlightsToSpans(
                _sourceLinesToOffsetSpans(
                  codeContent,
                  style: baseStyle.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        );

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final lineStart = _lineStartOffset(lines, lineIndex);
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_buildCodeBlock(codeLines));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeLines.add(_SourceLine(text: line, sourceStart: lineStart));
        continue;
      }
      if (trimmed.startsWith('>')) {
        final textStart = lineStart + line.indexOf('>') + 1;
        final quoteText = line.substring(line.indexOf('>') + 1);
        final contentStart =
            textStart + quoteText.length - quoteText.trimLeft().length;
        widgets.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: BricksSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: BricksSpacing.sm,
            vertical: BricksSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: quoteBlockColor,
            borderRadius: BorderRadius.circular(BricksRadius.sm),
          ),
          child: Text.rich(
            TextSpan(
              children: _applyHighlightsToSpans(
                _parseInlineMarkdownWithOffsets(
                  quoteText.trimLeft(),
                  sourceStart: contentStart,
                  baseStyle: baseStyle,
                  linkStyle: baseStyle.copyWith(color: linkColor),
                  headingLike: false,
                ),
              ),
            ),
          ),
        ));
        continue;
      }
      final table = _MarkdownTable.tryParseAt(lines, lineIndex);
      if (table != null) {
        final borderColor = textColor.withValues(alpha: 0.24);
        final headerLine = lines[lineIndex];
        final headerLineStart = lineStart;
        widgets.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: borderColor),
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: quoteBlockColor.withValues(alpha: 0.7),
                  ),
                  children: [
                    for (final cell in table.headers)
                      Padding(
                        padding: const EdgeInsets.all(BricksSpacing.xs),
                        child: Text.rich(
                          TextSpan(
                            children: _applyHighlightsToSpans(
                              _parseInlineMarkdownWithOffsets(
                                cell,
                                sourceStart: headerLineStart +
                                    _cellSourceOffset(headerLine, cell),
                                baseStyle: baseStyle.copyWith(
                                    fontWeight: FontWeight.w700),
                                linkStyle: baseStyle.copyWith(
                                  color: linkColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                headingLike: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
                  TableRow(
                    children: [
                      for (final cell in table.rows[rowIndex])
                        Padding(
                          padding: const EdgeInsets.all(BricksSpacing.xs),
                          child: Text.rich(
                            TextSpan(
                              children: _applyHighlightsToSpans(
                                _parseInlineMarkdownWithOffsets(
                                  cell,
                                  sourceStart: _lineStartOffset(
                                          lines, lineIndex + 2 + rowIndex) +
                                      _cellSourceOffset(
                                        lines[lineIndex + 2 + rowIndex],
                                        cell,
                                      ),
                                  baseStyle: baseStyle,
                                  linkStyle:
                                      baseStyle.copyWith(color: linkColor),
                                  headingLike: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
        lineIndex = table.lastLineIndex;
        continue;
      }
      final block = _MarkdownBlock.tryParse(line);
      final lineStyle = block.type == _MarkdownBlockType.heading
          ? baseStyle.copyWith(fontWeight: FontWeight.w700)
          : baseStyle;
      final blockSourceStart = lineStart + line.indexOf(block.text);
      final inlineSpans = _applyHighlightsToSpans(
        _parseInlineMarkdownWithOffsets(
          block.text,
          sourceStart: blockSourceStart,
          baseStyle: lineStyle,
          linkStyle: lineStyle.copyWith(color: linkColor),
          headingLike: false,
        ),
      );
      if (block.type == _MarkdownBlockType.unorderedList ||
          block.type == _MarkdownBlockType.orderedList) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: BricksSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.marker, style: lineStyle),
              const SizedBox(width: BricksSpacing.xs),
              Expanded(child: Text.rich(TextSpan(children: inlineSpans))),
            ],
          ),
        ));
        continue;
      }
      widgets.add(Text.rich(TextSpan(children: inlineSpans)));
    }

    // Handle unclosed code block (e.g. during streaming).
    if (inCodeBlock && codeLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeLines));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Convert a named or hex highlight color string to a [Color] with reduced
  /// opacity so the text beneath remains readable. All named colors use
  /// alpha = 0.45 as a consistent baseline; yellow is slightly more opaque
  /// (0.55) because it is brighter and needs higher saturation for contrast.
  static Color _parseHighlightColor(String color) {
    switch (color.toLowerCase()) {
      case 'yellow':
        return const Color(0xFFFFEB3B).withValues(alpha: 0.55);
      case 'green':
        return const Color(0xFF4CAF50).withValues(alpha: 0.45);
      case 'blue':
        return const Color(0xFF2196F3).withValues(alpha: 0.45);
      case 'red':
        return const Color(0xFFF44336).withValues(alpha: 0.45);
      case 'orange':
        return const Color(0xFFFF9800).withValues(alpha: 0.45);
      case 'purple':
        return const Color(0xFF9C27B0).withValues(alpha: 0.45);
      default:
        // Allow hex values like '#FFEB3B'. Parse as 6-digit RGB hex and
        // apply a standard background alpha.
        final hex = color.startsWith('#') ? color.substring(1) : color;
        final rgb = int.tryParse(hex, radix: 16);
        if (rgb != null && hex.length == 6) {
          return Color(rgb).withValues(
            red: ((rgb >> 16) & 0xFF) / 255.0,
            green: ((rgb >> 8) & 0xFF) / 255.0,
            blue: (rgb & 0xFF) / 255.0,
            alpha: 0.45,
          );
        }
        return const Color(0xFFFFEB3B).withValues(alpha: 0.45);
    }
  }
}

class _MarkdownTable {
  const _MarkdownTable({
    required this.headers,
    required this.rows,
    required this.lastLineIndex,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final int lastLineIndex;

  static final RegExp _separatorPattern = RegExp(
    r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
  );

  static _MarkdownTable? tryParseAt(List<String> lines, int startIndex) {
    if (startIndex + 1 >= lines.length) return null;
    final headerLine = lines[startIndex];
    final separatorLine = lines[startIndex + 1];
    if (!_looksLikeTableRow(headerLine) ||
        !_separatorPattern.hasMatch(separatorLine)) {
      return null;
    }

    final headers = _splitCells(headerLine);
    if (headers.isEmpty) return null;

    final rowLines = <List<String>>[];
    var currentIndex = startIndex + 2;
    while (currentIndex < lines.length) {
      final candidate = lines[currentIndex];
      if (!_looksLikeTableRow(candidate) || candidate.trim().isEmpty) {
        break;
      }
      final cells = _splitCells(candidate);
      if (cells.isEmpty) break;
      rowLines.add(_normalizeCells(cells, headers.length));
      currentIndex++;
    }

    return _MarkdownTable(
      headers: _normalizeCells(headers, headers.length),
      rows: rowLines,
      lastLineIndex: currentIndex - 1,
    );
  }

  static bool _looksLikeTableRow(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('|') || trimmed.endsWith('|');
  }

  static List<String> _splitCells(String line) {
    var normalized = line.trim();
    if (normalized.startsWith('|')) {
      normalized = normalized.substring(1);
    }
    if (normalized.endsWith('|')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.split('|').map((cell) => cell.trim()).toList();
  }

  static List<String> _normalizeCells(List<String> cells, int targetLength) {
    final normalized = List<String>.from(cells);
    if (normalized.length < targetLength) {
      normalized
          .addAll(List<String>.filled(targetLength - normalized.length, ''));
    } else if (normalized.length > targetLength) {
      return normalized.sublist(0, targetLength);
    }
    return normalized;
  }
}

class _SourceLine {
  const _SourceLine({required this.text, required this.sourceStart});

  final String text;
  final int sourceStart;
}

class _HighlightRange {
  const _HighlightRange({
    required this.highlightId,
    required this.selectedText,
    required this.start,
    required this.end,
    required this.backgroundColor,
  });

  final String highlightId;
  final String selectedText;
  final int start;
  final int end;
  final Color backgroundColor;
}

class _OffsetTextSpan {
  const _OffsetTextSpan({required this.span, required this.sourceStart});

  final TextSpan span;
  final int sourceStart;
}

class _RenderedTextIndex {
  const _RenderedTextIndex(this.text, this._sourceOffsets);

  final String text;
  final List<int> _sourceOffsets;

  int? sourceOffsetAt(int renderedOffset) {
    if (renderedOffset < 0 || renderedOffset >= _sourceOffsets.length) {
      return null;
    }
    return _sourceOffsets[renderedOffset];
  }

  int? sourceOffsetAfter(int renderedOffset) {
    if (_sourceOffsets.isEmpty) return null;
    if (renderedOffset <= 0) return _sourceOffsets.first;
    if (renderedOffset > _sourceOffsets.length) {
      return _sourceOffsets.last + 1;
    }
    return _sourceOffsets[renderedOffset - 1] + 1;
  }

  static _RenderedTextIndex fromMarkdownMessage(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final text = StringBuffer();
    final offsets = <int>[];
    final lines = normalized.split('\n');
    var inCodeBlock = false;
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final lineStart = _lineStartOffset(lines, lineIndex);
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
      } else if (inCodeBlock) {
        _appendMappedText(text, offsets, line, lineStart);
      } else {
        final block = _MarkdownBlock.tryParse(line);
        final blockStart = line.indexOf(block.text);
        _appendInlineMarkdownText(
          text,
          offsets,
          block.text,
          lineStart + (blockStart < 0 ? 0 : blockStart),
        );
      }
      if (lineIndex < lines.length - 1) {
        text.write('\n');
        offsets.add(lineStart + line.length);
      }
    }
    return _RenderedTextIndex(text.toString(), offsets);
  }
}

int _lineStartOffset(List<String> lines, int lineIndex) {
  var offset = 0;
  for (var i = 0; i < lineIndex; i++) {
    offset += lines[i].length + 1;
  }
  return offset;
}

int _cellSourceOffset(String line, String cell) {
  final index = line.indexOf(cell);
  return index < 0 ? 0 : index;
}

void _appendMappedText(
  StringBuffer text,
  List<int> offsets,
  String value,
  int sourceStart,
) {
  text.write(value);
  for (var i = 0; i < value.length; i++) {
    offsets.add(sourceStart + i);
  }
}

void _appendInlineMarkdownText(
  StringBuffer text,
  List<int> offsets,
  String source,
  int sourceStart,
) {
  var bold = false;
  var italic = false;
  var i = 0;
  while (i < source.length) {
    if (i + 1 < source.length) {
      final pair = source.substring(i, i + 2);
      if ((pair == '**' || pair == '__') &&
          (bold || source.indexOf(pair, i + 2) != -1)) {
        bold = !bold;
        i += 2;
        continue;
      }
    }
    final char = source[i];
    if ((char == '*' || char == '_') &&
        (italic || source.indexOf(char, i + 1) != -1)) {
      italic = !italic;
      i++;
      continue;
    }
    text.write(char);
    offsets.add(sourceStart + i);
    i++;
  }
}

List<_OffsetTextSpan> _sourceLinesToOffsetSpans(
  List<_SourceLine> lines, {
  required TextStyle style,
}) {
  final spans = <_OffsetTextSpan>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    spans.add(
      _OffsetTextSpan(
        span: TextSpan(text: line.text, style: style),
        sourceStart: line.sourceStart,
      ),
    );
    if (i < lines.length - 1) {
      spans.add(
        _OffsetTextSpan(
          span: TextSpan(text: '\n', style: style),
          sourceStart: line.sourceStart + line.text.length,
        ),
      );
    }
  }
  return spans;
}

List<_HighlightRange> _highlightRangesForMessage({
  required List<HighlightSpan> highlights,
  required String normalizedText,
}) {
  final ranges = <_HighlightRange>[];
  for (final highlight in highlights) {
    final startOffset = highlight.startOffset;
    final endOffset = highlight.endOffset;
    final bg =
        _AssistantMarkdownTextState._parseHighlightColor(highlight.color);
    if (startOffset != null &&
        endOffset != null &&
        startOffset >= 0 &&
        endOffset > startOffset &&
        startOffset < normalizedText.length) {
      ranges.add(
        _HighlightRange(
          highlightId: highlight.highlightId,
          selectedText: highlight.selectedText,
          start: startOffset,
          end: endOffset.clamp(0, normalizedText.length),
          backgroundColor: bg,
        ),
      );
      continue;
    }
    if (highlight.selectedText.isEmpty) continue;
    var searchStart = 0;
    while (true) {
      final idx = normalizedText.indexOf(highlight.selectedText, searchStart);
      if (idx == -1) break;
      ranges.add(
        _HighlightRange(
          highlightId: highlight.highlightId,
          selectedText: highlight.selectedText,
          start: idx,
          end: idx + highlight.selectedText.length,
          backgroundColor: bg,
        ),
      );
      searchStart = idx + highlight.selectedText.length;
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  return ranges;
}

List<InlineSpan> _splitOffsetSpansByHighlights({
  required List<_OffsetTextSpan> spans,
  required List<_HighlightRange> highlights,
  required TextStyle baseStyle,
  required BuildContext context,
  required void Function(String highlightId)? onDeleteHighlight,
  required List<GestureRecognizer> recognizers,
}) {
  final result = <InlineSpan>[];
  for (final offsetSpan in spans) {
    final spanText = offsetSpan.span.text ?? '';
    if (spanText.isEmpty) {
      result.add(offsetSpan.span);
      continue;
    }
    var cursor = 0;
    final spanStart = offsetSpan.sourceStart;
    final spanEnd = spanStart + spanText.length;
    for (final highlight in highlights) {
      final start = highlight.start > spanStart ? highlight.start : spanStart;
      final end = highlight.end < spanEnd ? highlight.end : spanEnd;
      if (end <= start) continue;
      final localStart = start - spanStart;
      final localEnd = end - spanStart;
      if (localStart > cursor) {
        result.add(
          TextSpan(
            text: spanText.substring(cursor, localStart),
            style: offsetSpan.span.style,
          ),
        );
      }
      final matchText = spanText.substring(localStart, localEnd);
      TapGestureRecognizer? recognizer;
      if (!kIsWeb && onDeleteHighlight != null) {
        final capturedHighlightId = highlight.highlightId;
        final capturedText = highlight.selectedText;
        recognizer = TapGestureRecognizer()
          ..onTapUp = (TapUpDetails details) {
            _showHighlightTapMenu(
              context: context,
              highlightId: capturedHighlightId,
              text: capturedText,
              position: details.globalPosition,
              onDeleteHighlight: onDeleteHighlight,
            );
          };
        recognizers.add(recognizer);
      }
      result.add(
        TextSpan(
          text: matchText,
          style: (offsetSpan.span.style ?? baseStyle).copyWith(
            backgroundColor: highlight.backgroundColor,
            decoration: TextDecoration.underline,
            decorationColor: highlight.backgroundColor.withValues(alpha: 1.0),
            decorationThickness: 2.0,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = localEnd;
    }
    if (cursor < spanText.length) {
      result.add(
        TextSpan(
          text: spanText.substring(cursor),
          style: offsetSpan.span.style,
        ),
      );
    }
  }
  return result;
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

List<_OffsetTextSpan> _parseInlineMarkdownWithOffsets(
  String source, {
  required int sourceStart,
  required TextStyle baseStyle,
  required TextStyle linkStyle,
  required bool headingLike,
}) {
  if (source.isEmpty) {
    return <_OffsetTextSpan>[
      _OffsetTextSpan(
        span: TextSpan(
          text: '',
          style: _styleFor(baseStyle, false, false, headingLike),
        ),
        sourceStart: sourceStart,
      )
    ];
  }

  final spans = <_OffsetTextSpan>[];
  final buffer = StringBuffer();
  var bufferStart = 0;
  var bold = false;
  var italic = false;
  var i = 0;

  void flush() {
    if (buffer.isEmpty) return;
    spans.addAll(
      _injectLinkOffsetSpans(
        buffer.toString(),
        sourceStart: sourceStart + bufferStart,
        style: _styleFor(baseStyle, bold, italic, headingLike),
        linkStyle: linkStyle,
      ),
    );
    buffer.clear();
  }

  while (i < source.length) {
    if (i + 1 < source.length) {
      final pair = source.substring(i, i + 2);
      if (pair == '**' || pair == '__') {
        // Only treat as a delimiter when toggling off (already open) or
        // when a matching closing pair exists later in the string.
        if (bold || source.indexOf(pair, i + 2) != -1) {
          flush();
          bold = !bold;
          i += 2;
          bufferStart = i;
          continue;
        }
      }
    }
    final char = source[i];
    if (char == '*' || char == '_') {
      // Only treat as a delimiter when toggling off (already open) or
      // when a matching closing character exists later in the string.
      if (italic || source.indexOf(char, i + 1) != -1) {
        flush();
        italic = !italic;
        i++;
        bufferStart = i;
        continue;
      }
    }
    if (buffer.isEmpty) bufferStart = i;
    buffer.write(char);
    i++;
  }

  flush();
  return spans;
}

List<_OffsetTextSpan> _injectLinkOffsetSpans(
  String text, {
  required int sourceStart,
  required TextStyle style,
  required TextStyle linkStyle,
}) {
  final urlPattern = RegExp(r'https?://[^\s]+');
  final expanded = <_OffsetTextSpan>[];
  var cursor = 0;
  for (final match in urlPattern.allMatches(text)) {
    if (match.start > cursor) {
      expanded.add(
        _OffsetTextSpan(
          span: TextSpan(
            text: text.substring(cursor, match.start),
            style: style,
          ),
          sourceStart: sourceStart + cursor,
        ),
      );
    }
    expanded.add(
      _OffsetTextSpan(
        span: TextSpan(
          text: text.substring(match.start, match.end),
          style: linkStyle,
        ),
        sourceStart: sourceStart + match.start,
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    expanded.add(
      _OffsetTextSpan(
        span: TextSpan(text: text.substring(cursor), style: style),
        sourceStart: sourceStart + cursor,
      ),
    );
  }
  if (expanded.isEmpty) {
    expanded.add(
      _OffsetTextSpan(
        span: TextSpan(text: text, style: style),
        sourceStart: sourceStart,
      ),
    );
  }
  return expanded;
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
    fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
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
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
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

// ---------------------------------------------------------------------------
// Context menu shown on long-press of a user bubble.
// Uses showGeneralDialog with Duration.zero so the menu appears instantly
// without any open/close animation.
// ---------------------------------------------------------------------------

class _UserMessageContextMenu extends StatelessWidget {
  const _UserMessageContextMenu({
    required this.position,
    required this.screenSize,
    required this.message,
  });

  final Offset position;
  final Size screenSize;
  final ChatMessage message;

  static const double _menuWidth = 220.0;
  static const double _itemHeight = 48.0;
  static const double _menuEdgeMargin = 8.0;

  @override
  Widget build(BuildContext context) {
    // Estimate clamped position; footer height is approximate (2 labelSmall lines + padding)
    const estimatedFooterHeight = 48.0;
    final menuHeight = _itemHeight * 3 + estimatedFooterHeight;

    double left = position.dx;
    double top = position.dy;
    if (left + _menuWidth > screenSize.width - _menuEdgeMargin) {
      left = screenSize.width - _menuWidth - _menuEdgeMargin;
    }
    if (top + menuHeight > screenSize.height - _menuEdgeMargin) {
      top = screenSize.height - menuHeight - _menuEdgeMargin;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MenuItem(label: '复制', value: 'copy'),
                _MenuItem(label: '分叉（待开发）', value: 'branch'),
                _MenuItem(label: '重发（待开发）', value: 'resend'),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'message id: ${message.messageId ?? '-'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      Text(
                        'task id: ${message.taskId ?? '-'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: SizedBox(
        height: _UserMessageContextMenu._itemHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent-loop status rows for tool_call_start, reasoning, and step_text phases.
// ---------------------------------------------------------------------------

/// Renders a single agent-loop status message inline within the message list.
///
/// | phase            | visual                                          |
/// |------------------|-------------------------------------------------|
/// | tool_call_start  | spinning ⚙ icon + "Calling toolName…"          |
/// | reasoning        | 💭 expandable thought block                     |
/// | step_text        | assistant text with left accent border          |
///
/// Note: `tool_call` phase messages are routed to the standard assistant
/// bubble renderer (not this widget) so their content renders with markdown.
class _AgentLoopStatusRow extends StatefulWidget {
  const _AgentLoopStatusRow({
    required this.phase,
    required this.chatColors,
    this.toolName,
    this.content = '',
    this.taskState,
  });

  final String phase;
  final String? toolName;
  final String content;
  final ChatColors chatColors;
  final ChatTaskState? taskState;

  @override
  State<_AgentLoopStatusRow> createState() => _AgentLoopStatusRowState();
}

class _AgentLoopStatusRowState extends State<_AgentLoopStatusRow> {
  bool _reasoningExpanded = false;

  @override
  Widget build(BuildContext context) {
    final chatColors = widget.chatColors;

    switch (widget.phase) {
      case 'tool_call_start':
        final label =
            widget.toolName != null ? '正在调用 ${widget.toolName}…' : '正在调用工具…';
        final doneLabel =
            widget.toolName != null ? '已调用 ${widget.toolName}' : '已调用工具';
        final isDone = widget.taskState == ChatTaskState.completed;
        return Padding(
          padding: const EdgeInsets.only(
            left: BricksSpacing.xs,
            right: BricksSpacing.xs,
            bottom: BricksSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: isDone
                    ? Icon(
                        Icons.check_circle_outline,
                        size: 12,
                        color: chatColors.agentAccent,
                      )
                    : CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          chatColors.agentAccent,
                        ),
                      ),
              ),
              const SizedBox(width: BricksSpacing.xs),
              Text(
                isDone ? doneLabel : label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: chatColors.metaText,
                    ),
              ),
            ],
          ),
        );

      case 'reasoning':
        final hasContent = widget.content.trim().isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(
            left: BricksSpacing.xs,
            right: BricksSpacing.xs,
            bottom: BricksSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: hasContent
                    ? () => setState(
                          () => _reasoningExpanded = !_reasoningExpanded,
                        )
                    : null,
                borderRadius: BorderRadius.circular(BricksRadius.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 14,
                      color: chatColors.metaText,
                    ),
                    const SizedBox(width: BricksSpacing.xs),
                    Text(
                      '思考过程',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: chatColors.metaText,
                          ),
                    ),
                    if (hasContent) ...[
                      const SizedBox(width: BricksSpacing.xs),
                      Icon(
                        _reasoningExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 14,
                        color: chatColors.metaText,
                      ),
                    ],
                  ],
                ),
              ),
              if (_reasoningExpanded && hasContent)
                Padding(
                  padding: const EdgeInsets.only(top: BricksSpacing.xs),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(BricksSpacing.sm),
                    decoration: BoxDecoration(
                      color: chatColors.quoteBackground,
                      borderRadius: BorderRadius.circular(BricksRadius.sm),
                    ),
                    child: Text(
                      widget.content,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: chatColors.onMessageAssistant,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        );

      case 'step_text':
        if (widget.content.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(
            left: BricksSpacing.xs,
            right: BricksSpacing.xs,
            bottom: BricksSpacing.xs,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: chatColors.agentAccent.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: BricksSpacing.xs),
                Expanded(
                  child: Text(
                    widget.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: chatColors.onMessageAssistant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        // Unknown/future phases: render as a small muted summary.
        if (widget.content.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(
            left: BricksSpacing.xs,
            right: BricksSpacing.xs,
            bottom: BricksSpacing.xs,
          ),
          child: Text(
            widget.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: chatColors.metaText,
                ),
          ),
        );
    }
  }
}
