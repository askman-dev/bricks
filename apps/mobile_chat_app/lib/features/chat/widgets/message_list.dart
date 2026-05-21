import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';
import '../chat_message.dart';
import '../text_highlight_api_service.dart';

// Extra bottom padding as a fraction of screen height, so the latest user
// message can be anchored above the bottom while leaving room for the
// assistant reply to stream below it.
const double _kBottomPaddingRatio = 1 / 3;

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

  /// Called when the user taps Remove highlight in the floating highlight menu.
  final void Function(String highlightId)? onDeleteHighlight;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();
  static const double _kJumpButtonShowScreens = 2;
  bool _showJumpToLatestButton = false;
  double _listBottomPadding = 0;

  // Tracks the most recent text selection so the context menu action can read
  // it when Flutter invokes contextMenuBuilder.
  String _lastSelectedText = '';
  Offset? _selectionToolbarPosition;

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
        ).showSnackBar(const SnackBar(content: Text('Copied')));
        break;
      case 'branch':
      case 'resend':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Coming soon')));
        break;
    }
  }

  void _hideSelectionToolbar() {
    if (_selectionToolbarPosition == null) return;
    setState(() {
      _selectionToolbarPosition = null;
    });
  }

  void _showSelectionToolbarAt(Offset globalPosition) {
    if (_lastSelectedText.trim().isEmpty) {
      _hideSelectionToolbar();
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final local = renderObject.globalToLocal(globalPosition);
    setState(() {
      _selectionToolbarPosition = local;
    });
  }

  _ResolvedAssistantSelection? _currentResolvedSelection() {
    return _resolveMessageListSelection(
      messages: widget.messages,
      selectedText: _lastSelectedText,
      highlightsByMessageId: widget.highlights,
    );
  }

  Future<void> _copyCurrentSelection() async {
    final selectedText = _lastSelectedText;
    if (selectedText.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: selectedText));
    _hideSelectionToolbar();
  }

  void _handleSelectionToolbarAction(_ResolvedAssistantSelection resolved) {
    final matchingHighlightId = resolved.matchingHighlightId;
    if (matchingHighlightId != null && widget.onDeleteHighlight != null) {
      widget.onDeleteHighlight!(matchingHighlightId);
      _hideSelectionToolbar();
      return;
    }
    if (widget.onHighlight == null) return;
    widget.onHighlight!(
      resolved.messageId,
      resolved.selectedText,
      resolved.startOffset,
      resolved.endOffset,
    );
    _hideSelectionToolbar();
  }

  bool _isToolLoopMessage(ChatMessage message) {
    if (message.role == 'user') return false;
    return message.agentLoopPhase == 'tool_call_start' ||
        message.agentLoopPhase == 'tool_call';
  }

  int _toolGroupEndIndex(List<ChatMessage> messages, int startIndex) {
    var endIndex = startIndex;
    while (endIndex + 1 < messages.length &&
        _isToolLoopMessage(messages[endIndex + 1])) {
      endIndex++;
    }
    return endIndex;
  }

  Widget _buildToolGroupItem(
    BuildContext context,
    int startIndex,
    int endIndex, {
    bool hideMeta = false,
  }) {
    final messages = widget.messages;
    final first = messages[startIndex];
    final groupMessages = messages.sublist(startIndex, endIndex + 1);
    final chatColors =
        Theme.of(context).extension<ChatColors>() ?? ChatColors.light;
    final itemKey = startIndex == _focusedIndex ? _focusedItemKey : null;
    final startMessages = groupMessages
        .where((message) => message.agentLoopPhase == 'tool_call_start')
        .toList(growable: false);
    final total = startMessages.isNotEmpty
        ? startMessages.length
        : groupMessages
            .where((message) => message.agentLoopPhase == 'tool_call')
            .length;
    final completed = startMessages.isNotEmpty
        ? startMessages
            .where((message) => message.taskState == ChatTaskState.completed)
            .length
        : total;
    final isFinalized = completed >= total && total > 0;
    final labelPrefix = isFinalized ? 'Thinking complete' : 'Thinking';
    final label = '$labelPrefix $completed/$total';
    final detail = _agentLoopDetails(groupMessages);

    return Align(
      key: itemKey,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (first.agentName != null || first.model != null)
            _assistantAttributionHeader(
              context: context,
              message: first,
              chatColors: chatColors,
            ),
          _AgentLoopToolGroupRow(
            label: label,
            isFinalized: isFinalized,
            chatColors: chatColors,
            onTap: detail.trim().isEmpty
                ? null
                : () => _showAgentLoopDetails(
                      title: label,
                      details: detail,
                    ),
          ),
          if (!hideMeta)
            Padding(
              padding: const EdgeInsets.only(
                left: BricksSpacing.xs,
                right: BricksSpacing.xs,
                bottom: BricksSpacing.md,
              ),
              child: Text(
                _messageMetaLine(first),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: chatColors.metaText,
                    ),
              ),
            )
          else
            const SizedBox(height: BricksSpacing.xs),
        ],
      ),
    );
  }

  String _agentLoopDetails(List<ChatMessage> messages) {
    final parts = <String>[];
    for (final message in messages) {
      final phase = message.agentLoopPhase ?? 'agent_loop';
      final tool = message.agentLoopTool;
      final content = message.content.trim();
      if (content.isEmpty) {
        if (tool != null && tool.trim().isNotEmpty) {
          parts.add('$phase: $tool');
        }
        continue;
      }
      parts.add(tool == null ? content : '$phase: $tool\n$content');
    }
    return parts.join('\n\n');
  }

  Future<void> _showAgentLoopDetails({
    required String title,
    required String details,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(details),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _shouldAttachAssistantTextToPreviousToolGroup(
    List<ChatMessage> messages,
    int index,
  ) {
    if (index <= 0) return false;
    final message = messages[index];
    if (message.role != 'assistant') return false;
    if (message.agentLoopPhase != null) return false;
    if (_isAssistantDispatchPlaceholder(message)) return false;
    return _isToolLoopMessage(messages[index - 1]);
  }

  bool _toolGroupShouldAttachNextText(
    List<ChatMessage> messages,
    int endIndex,
  ) {
    if (endIndex + 1 >= messages.length) return false;
    return _shouldAttachAssistantTextToPreviousToolGroup(
      messages,
      endIndex + 1,
    );
  }

  bool _shouldRenderToolGroupBeforePlaceholder(
    List<ChatMessage> messages,
    int index,
  ) {
    if (index + 1 >= messages.length) return false;
    final message = messages[index];
    final next = messages[index + 1];
    if (!_isAssistantDispatchPlaceholder(message)) return false;
    if (!_isToolLoopMessage(next)) return false;
    if (message.taskId == null || next.taskId == null) return false;
    return message.taskId == next.taskId;
  }

  Widget _assistantAttributionHeader({
    required BuildContext context,
    required ChatMessage message,
    required ChatColors chatColors,
  }) {
    return Padding(
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
            message.agentName ?? message.model ?? '',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: chatColors.agentIdentity,
                ),
          ),
          if (message.nodeType?.trim().isNotEmpty == true) ...[
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
                message.nodeType!.trim(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: chatColors.onAgentBadgeContainer,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Builds a single message row for the given [index] in [widget.messages].
  // Extracted from build() so that the non-builder ListView can call it in a
  // simple for-loop while keeping the item rendering logic in one place.
  Widget _buildMessageItem(
    BuildContext context,
    int index, {
    bool suppressAssistantHeader = false,
  }) {
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
          if (!isUser &&
              !suppressAssistantHeader &&
              (msg.agentName != null || msg.model != null))
            _assistantAttributionHeader(
              context: context,
              message: msg,
              chatColors: chatColors,
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
                    'Processing...',
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
    final messageItems = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      if (_shouldRenderToolGroupBeforePlaceholder(messages, i)) {
        final endIndex = _toolGroupEndIndex(messages, i + 1);
        messageItems.add(
          _buildToolGroupItem(
            context,
            i + 1,
            endIndex,
            hideMeta: true,
          ),
        );
        messageItems.add(_buildMessageItem(context, i));
        i = endIndex;
        continue;
      }
      if (_isToolLoopMessage(messages[i])) {
        final endIndex = _toolGroupEndIndex(messages, i);
        messageItems.add(
          _buildToolGroupItem(
            context,
            i,
            endIndex,
            hideMeta: _toolGroupShouldAttachNextText(messages, endIndex),
          ),
        );
        i = endIndex;
        continue;
      }
      messageItems.add(
        _buildMessageItem(
          context,
          i,
          suppressAssistantHeader:
              _shouldAttachAssistantTextToPreviousToolGroup(messages, i),
        ),
      );
    }

    // All messages in the initial load are bounded (≤ 20 items). Building
    // them eagerly with a non-builder ListView gives an accurate
    // maxScrollExtent from the very first frame, so _scrollToFocusedUserMessage
    // can call Scrollable.ensureVisible directly without any jumpTo/retry hack.
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) => _hideSelectionToolbar(),
          onPointerUp: (event) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showSelectionToolbarAt(event.position);
            });
          },
          child: SelectionArea(
            onSelectionChanged: (value) {
              _lastSelectedText = value?.plainText ?? '';
              if (_lastSelectedText.trim().isEmpty) {
                _hideSelectionToolbar();
              }
            },
            contextMenuBuilder: (ctx, selectableRegionState) {
              final resolved = _currentResolvedSelection();
              final extraItems = <ContextMenuButtonItem>[];
              final matchingHighlightId = resolved?.matchingHighlightId;
              if (matchingHighlightId != null &&
                  widget.onDeleteHighlight != null) {
                extraItems.add(
                  ContextMenuButtonItem(
                    label: 'Remove highlight',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      widget.onDeleteHighlight!(matchingHighlightId);
                    },
                  ),
                );
              } else if (resolved != null && widget.onHighlight != null) {
                extraItems.add(
                  ContextMenuButtonItem(
                    label: 'Highlight',
                    onPressed: () {
                      ContextMenuController.removeAny();
                      widget.onHighlight!(
                        resolved.messageId,
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
                children: messageItems,
              ),
            ),
          ),
        ),
        if (_selectionToolbarPosition != null)
          Builder(
            builder: (context) {
              final resolved = _currentResolvedSelection();
              if (resolved == null) return const SizedBox.shrink();
              final position = _selectionToolbarPosition!;
              final size = MediaQuery.sizeOf(context);
              final top = (position.dy - 52)
                  .clamp(BricksSpacing.sm, size.height - 52)
                  .toDouble();
              final actionLabel = _selectionActionLabelForCallbacks(
                resolved: resolved,
                onDeleteHighlight: widget.onDeleteHighlight,
                onHighlight: widget.onHighlight,
              );
              return Positioned(
                left: BricksSpacing.sm,
                right: BricksSpacing.sm,
                top: top,
                child: Align(
                  alignment: Alignment.topCenter,
                  widthFactor: 1,
                  child: _SelectionFloatingToolbar(
                    actionLabel: actionLabel,
                    onCopy: _copyCurrentSelection,
                    onAction: actionLabel == null
                        ? null
                        : () => _handleSelectionToolbarAction(resolved),
                  ),
                ),
              );
            },
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

String? _selectionActionLabelForCallbacks({
  required _ResolvedAssistantSelection resolved,
  required void Function(String highlightId)? onDeleteHighlight,
  required void Function(
    String messageId,
    String selectedText,
    int? startOffset,
    int? endOffset,
  )? onHighlight,
}) {
  if (resolved.matchingHighlightId != null) {
    return onDeleteHighlight == null ? null : 'Remove highlight';
  }
  return onHighlight == null ? null : 'Highlight';
}

class _SelectionFloatingToolbar extends StatelessWidget {
  const _SelectionFloatingToolbar({
    required this.actionLabel,
    required this.onCopy,
    required this.onAction,
  });

  final String? actionLabel;
  final VoidCallback onCopy;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BricksSpacing.sm,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SelectionToolbarButton(
              label: 'Copy',
              foregroundColor: colorScheme.onInverseSurface,
              onPressed: onCopy,
            ),
            _SelectionToolbarButton(
              label: actionLabel ?? 'Highlight',
              foregroundColor: colorScheme.onInverseSurface,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionToolbarButton extends StatefulWidget {
  const _SelectionToolbarButton({
    required this.label,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  State<_SelectionToolbarButton> createState() =>
      _SelectionToolbarButtonState();
}

class _SelectionToolbarButtonState extends State<_SelectionToolbarButton> {
  bool _pressed = false;

  void _trigger() {
    if (_pressed) return;
    _pressed = true;
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final foregroundColor = enabled
        ? widget.foregroundColor
        : widget.foregroundColor.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled ? (_) => _trigger() : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BricksSpacing.sm,
              ),
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                    ),
              ),
            ),
          ),
        ),
      ),
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
    required this.messageId,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    this.matchingHighlightId,
  });

  final String messageId;
  final String selectedText;
  final int? startOffset;
  final int? endOffset;
  final String? matchingHighlightId;
}

_ResolvedAssistantSelection? _resolveMessageListSelection({
  required List<ChatMessage> messages,
  required String selectedText,
  required Map<String, List<HighlightSpan>> highlightsByMessageId,
}) {
  final normalizedSelection =
      selectedText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalizedSelection.trim().isEmpty) return null;

  for (final message in messages) {
    if (message.role != 'assistant') continue;
    final messageId = message.messageId;
    if (messageId == null) continue;

    final mapping = _RenderedTextIndex.fromMarkdownMessage(message.content);
    final renderedStart = mapping.text.indexOf(normalizedSelection);
    int? startOffset;
    int? endOffset;
    if (renderedStart != -1) {
      startOffset = mapping.sourceOffsetAt(renderedStart);
      endOffset = mapping.sourceOffsetAfter(
        renderedStart + normalizedSelection.length,
      );
    } else {
      final normalizedMessage =
          message.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final rawStart = normalizedMessage.indexOf(normalizedSelection);
      if (rawStart == -1) continue;
      startOffset = rawStart;
      endOffset = rawStart + normalizedSelection.length;
    }

    String? matchingHighlightId;
    for (final highlight in highlightsByMessageId[messageId] ?? const []) {
      if (!_highlightMatchesSelection(
        highlight: highlight,
        selectedText: normalizedSelection,
        startOffset: startOffset,
        endOffset: endOffset,
      )) {
        continue;
      }
      matchingHighlightId = highlight.highlightId;
      break;
    }

    return _ResolvedAssistantSelection(
      messageId: messageId,
      selectedText: normalizedSelection,
      startOffset: startOffset,
      endOffset: endOffset,
      matchingHighlightId: matchingHighlightId,
    );
  }

  return null;
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
/// The menu offers Copy and Remove highlight actions.
void _showHighlightTapMenu({
  required BuildContext context,
  required String highlightId,
  required String text,
  required Offset position,
  required void Function(String highlightId) onDeleteHighlight,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, __) {
      const toolbarHeight = 52.0;
      final top = (position.dy - toolbarHeight - BricksSpacing.xs)
          .clamp(BricksSpacing.sm, overlay.size.height - toolbarHeight)
          .toDouble();
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: BricksSpacing.sm,
            right: BricksSpacing.sm,
            top: top,
            child: Align(
              alignment: Alignment.topCenter,
              widthFactor: 1,
              child: _SelectionFloatingToolbar(
                actionLabel: 'Remove highlight',
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.of(dialogContext).pop();
                },
                onAction: () {
                  onDeleteHighlight(highlightId);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ),
          ),
        ],
      );
    },
  );
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

  /// Called when the user taps Remove highlight in the floating highlight popup.
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
        final listLeftPadding = BricksSpacing.md * (block.listLevel + 1);
        widgets.add(Padding(
          padding: EdgeInsets.only(left: listLeftPadding),
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
  return _mergeHighlightRanges(ranges, normalizedText);
}

List<_HighlightRange> _mergeHighlightRanges(
  List<_HighlightRange> ranges,
  String normalizedText,
) {
  if (ranges.length < 2) return ranges;
  final merged = <_HighlightRange>[];
  var current = ranges.first;
  for (final next in ranges.skip(1)) {
    if (next.start > current.end) {
      merged.add(current);
      current = next;
      continue;
    }
    final end = next.end > current.end ? next.end : current.end;
    current = _HighlightRange(
      highlightId: current.highlightId,
      selectedText: normalizedText.substring(current.start, end),
      start: current.start,
      end: end,
      backgroundColor: current.backgroundColor,
    );
  }
  merged.add(current);
  return merged;
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
      if (localEnd <= cursor) continue;
      if (localStart > cursor) {
        result.add(
          TextSpan(
            text: spanText.substring(cursor, localStart),
            style: offsetSpan.span.style,
          ),
        );
      }
      final effectiveStart = localStart < cursor ? cursor : localStart;
      final matchText = spanText.substring(effectiveStart, localEnd);
      TapGestureRecognizer? recognizer;
      if (onDeleteHighlight != null) {
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
    this.listLevel = 0,
  });

  final _MarkdownBlockType type;
  final String text;
  final String marker;
  final int listLevel;

  static final RegExp _headingPattern = RegExp(r'^\s{0,3}(#{1,6})\s+(.*)$');
  static final RegExp _unorderedListPattern = RegExp(r'^(\s*)([-*+])\s+(.*)$');
  static final RegExp _orderedListPattern = RegExp(r'^(\s*)(\d+)\.\s+(.*)$');

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
        marker: unorderedMatch.group(2) ?? '•',
        text: unorderedMatch.group(3) ?? '',
        listLevel: _listLevelFromIndent(unorderedMatch.group(1) ?? ''),
      );
    }

    final orderedMatch = _orderedListPattern.firstMatch(line);
    if (orderedMatch != null) {
      return _MarkdownBlock(
        type: _MarkdownBlockType.orderedList,
        marker: '${orderedMatch.group(2)}.',
        text: orderedMatch.group(3) ?? '',
        listLevel: _listLevelFromIndent(orderedMatch.group(1) ?? ''),
      );
    }

    return _MarkdownBlock(type: _MarkdownBlockType.paragraph, text: line);
  }
}

int _listLevelFromIndent(String indent) {
  final spaces = indent.replaceAll('\t', '    ').length;
  return spaces ~/ 2;
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
                _MenuItem(label: 'Copy', value: 'copy'),
                _MenuItem(label: 'Branch (coming soon)', value: 'branch'),
                _MenuItem(label: 'Resend (coming soon)', value: 'resend'),
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
  Future<void> _showReasoningDetails(BuildContext context, String title) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(widget.content),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatColors = widget.chatColors;

    switch (widget.phase) {
      case 'tool_call_start':
        final label = widget.toolName != null
            ? 'Calling ${widget.toolName}...'
            : 'Calling tool...';
        final doneLabel = widget.toolName != null
            ? 'Called ${widget.toolName}'
            : 'Called tool';
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
        final label = widget.taskState == ChatTaskState.completed
            ? 'Thinking complete'
            : 'Thinking';
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
                    ? () => _showReasoningDetails(context, label)
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
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: chatColors.metaText,
                          ),
                    ),
                    if (hasContent) ...[
                      const SizedBox(width: BricksSpacing.xs),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: chatColors.metaText,
                      ),
                    ],
                  ],
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

class _AgentLoopToolGroupRow extends StatelessWidget {
  const _AgentLoopToolGroupRow({
    required this.label,
    required this.isFinalized,
    required this.chatColors,
    this.onTap,
  });

  final String label;
  final bool isFinalized;
  final ChatColors chatColors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: BricksSpacing.xs,
        right: BricksSpacing.xs,
        bottom: BricksSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BricksRadius.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: isFinalized
                  ? Icon(
                      Icons.check_circle_outline,
                      size: 14,
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
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: chatColors.metaText,
                  ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: BricksSpacing.xs),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: chatColors.metaText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
