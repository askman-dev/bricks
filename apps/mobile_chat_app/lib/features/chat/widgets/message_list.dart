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
  });

  final String highlightId;
  final String selectedText;
  final String color;

  static HighlightSpan fromHighlight(TextHighlight h) => HighlightSpan(
        highlightId: h.id,
        selectedText: h.selectedText,
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

  // Tracks the most recent text selection so the context menu "Highlight"
  // action can read it without requiring currentSelection from the state.
  String _lastSelectedText = '';

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
                      _AssistantMarkdownText(
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
        SelectionArea(
          onSelectionChanged: (value) {
            _lastSelectedText = value?.plainText ?? '';
          },
          contextMenuBuilder: (ctx, selectableRegionState) {
            final extraItems = <ContextMenuButtonItem>[
              if (widget.onHighlight != null)
                ContextMenuButtonItem(
                  label: '划线',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    final plainText = _lastSelectedText;
                    if (plainText.isEmpty) return;
                    // Find the first assistant message whose content
                    // contains the selected text and fire the callback.
                    for (final m in widget.messages) {
                      if (m.role != 'assistant') continue;
                      // Skip messages without a stable ID — we cannot
                      // persist a highlight without one.
                      final messageId = m.messageId;
                      if (messageId == null) continue;
                      final idx = m.content.indexOf(plainText);
                      if (idx != -1) {
                        widget.onHighlight!(
                          messageId,
                          plainText,
                          idx,
                          idx + plainText.length,
                        );
                        return;
                      }
                    }
                    // No message with a valid ID contains the selected
                    // text — silently skip rather than emitting an
                    // invalid (empty) messageId to the backend.
                  },
                ),
            ];
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: [
                ...selectableRegionState.contextMenuButtonItems,
                ...extraItems,
              ],
            );
          },
          child: SingleChildScrollView(
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
    final normalizedText =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalizedText.split('\n');
    final widgets = <Widget>[];
    var inCodeBlock = false;
    final codeLines = <String>[];

    // Build a list of highlight lookup items (plain text, color, id).
    // We search directly within each span's rendered text at draw time so
    // that markdown delimiters (**, _, etc.) never corrupt the match offsets.
    final highlightItems = <({String text, Color bg, String highlightId})>[];
    if (highlights.isNotEmpty) {
      for (final h in highlights) {
        if (h.selectedText.isNotEmpty) {
          highlightItems.add((
            text: h.selectedText,
            bg: _parseHighlightColor(h.color),
            highlightId: h.highlightId,
          ));
        }
      }
    }

    // Split a single TextSpan into highlighted/un-highlighted fragments by
    // searching for each highlight text directly within the span's plain text.
    // Because we work on rendered (markdown-stripped) span text, markdown
    // delimiters do not shift offsets.
    List<InlineSpan> _splitSpanByHighlights(TextSpan span) {
      final spanText = span.text ?? '';
      if (spanText.isEmpty) return [span];

      // Collect all match ranges within this span.
      final ranges = <({int start, int end, Color bg, String highlightId})>[];
      for (final h in highlightItems) {
        var searchStart = 0;
        while (true) {
          final idx = spanText.indexOf(h.text, searchStart);
          if (idx == -1) break;
          ranges.add((
            start: idx,
            end: idx + h.text.length,
            bg: h.bg,
            highlightId: h.highlightId,
          ));
          searchStart = idx + h.text.length;
        }
      }
      if (ranges.isEmpty) return [span];
      // Sort by start position and merge overlapping or adjacent ranges (keep first color/id).
      ranges.sort((a, b) => a.start.compareTo(b.start));
      final merged = <({int start, int end, Color bg, String highlightId})>[];
      for (final r in ranges) {
        if (merged.isNotEmpty && r.start <= merged.last.end) {
          final last = merged.removeLast();
          merged.add((
            start: last.start,
            end: r.end > last.end ? r.end : last.end,
            bg: last.bg,
            highlightId: last.highlightId,
          ));
        } else {
          merged.add(r);
        }
      }
      // Slice the span at highlight boundaries.
      final result = <InlineSpan>[];
      var cursor = 0;
      for (final r in merged) {
        if (r.start > cursor) {
          result.add(TextSpan(text: spanText.substring(cursor, r.start), style: span.style));
        }
        final matchText = spanText.substring(r.start, r.end);
        // Build a tap recognizer so tapping the highlighted span opens the
        // floating delete/copy menu. Track it in _recognizers for disposal.
        TapGestureRecognizer? recognizer;
        if (onDeleteHighlight != null) {
          final capturedHighlightId = r.highlightId;
          final capturedText = matchText;
          Offset? tapPosition;
          recognizer = TapGestureRecognizer()
            ..onTapDown = (TapDownDetails details) {
              // Record position here; the menu is shown only on completed
              // tap (onTap) so that long-press text selection is unaffected.
              tapPosition = details.globalPosition;
            }
            ..onTap = () {
              final pos = tapPosition;
              if (pos == null) return;
              _showHighlightTapMenu(
                context: context,
                highlightId: capturedHighlightId,
                text: capturedText,
                position: pos,
                onDeleteHighlight: onDeleteHighlight,
              );
            };
          _recognizers.add(recognizer);
        }
        result.add(TextSpan(
          text: matchText,
          style: (span.style ?? baseStyle).copyWith(
            backgroundColor: r.bg,
            decoration: TextDecoration.underline,
            decorationColor: r.bg.withValues(alpha: 1.0),
            decorationThickness: 2.0,
          ),
          recognizer: recognizer,
        ));
        cursor = r.end;
      }
      if (cursor < spanText.length) {
        result.add(TextSpan(text: spanText.substring(cursor), style: span.style));
      }
      return result;
    }

    List<InlineSpan> _applyHighlightsToSpans(List<InlineSpan> spans) {
      if (highlightItems.isEmpty) return spans;
      final result = <InlineSpan>[];
      for (final span in spans) {
        if (span is TextSpan) {
          result.addAll(_splitSpanByHighlights(span));
        } else {
          result.add(span);
        }
      }
      return result;
    }

    Widget _buildCodeBlock(List<String> codeContent) => Container(
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
          child: Text(
            codeContent.join('\n'),
            style: baseStyle.copyWith(fontFamily: 'monospace'),
          ),
        );

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
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
        codeLines.add(line);
        continue;
      }
      if (trimmed.startsWith('>')) {
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
          child: Text(trimmed.substring(1).trimLeft(), style: baseStyle),
        ));
        continue;
      }
      final table = _MarkdownTable.tryParseAt(lines, lineIndex);
      if (table != null) {
        final borderColor = textColor.withValues(alpha: 0.24);
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
                            children: _parseInlineMarkdown(
                              cell,
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
                  ],
                ),
                for (final row in table.rows)
                  TableRow(
                    children: [
                      for (final cell in row)
                        Padding(
                          padding: const EdgeInsets.all(BricksSpacing.xs),
                          child: Text.rich(
                            TextSpan(
                              children: _parseInlineMarkdown(
                                cell,
                                baseStyle: baseStyle,
                                linkStyle: baseStyle.copyWith(color: linkColor),
                                headingLike: false,
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
      var inlineSpans = _parseInlineMarkdown(
        block.text,
        baseStyle: lineStyle,
        linkStyle: lineStyle.copyWith(color: linkColor),
        headingLike: false,
      );
      // Compute the text-only offset of block.text within the line so we can
      // map highlight ranges from the full message text into this span list.
      inlineSpans = _applyHighlightsToSpans(inlineSpans);
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
  required TextStyle linkStyle,
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
        // Only treat as a delimiter when toggling off (already open) or
        // when a matching closing pair exists later in the string.
        if (bold || source.indexOf(pair, i + 2) != -1) {
          flush();
          bold = !bold;
          i += 2;
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
        continue;
      }
    }
    buffer.write(char);
    i++;
  }

  flush();
  return _injectLinkSpans(spans, baseStyle: baseStyle, linkStyle: linkStyle);
}

List<InlineSpan> _injectLinkSpans(
  List<InlineSpan> spans, {
  required TextStyle baseStyle,
  required TextStyle linkStyle,
}) {
  final urlPattern = RegExp(r'https?://[^\s]+');
  final expanded = <InlineSpan>[];
  for (final span in spans) {
    if (span is! TextSpan || (span.text ?? '').isEmpty) {
      expanded.add(span);
      continue;
    }
    final text = span.text!;
    var cursor = 0;
    for (final match in urlPattern.allMatches(text)) {
      if (match.start > cursor) {
        expanded.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: span.style ?? baseStyle,
          ),
        );
      }
      expanded.add(
        TextSpan(
          text: match.group(0),
          style: (span.style ?? baseStyle).merge(linkStyle),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      expanded.add(
        TextSpan(
          text: text.substring(cursor),
          style: span.style ?? baseStyle,
        ),
      );
    }
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
