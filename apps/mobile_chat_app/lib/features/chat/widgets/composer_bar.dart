import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Actions available in the composer popup menu.
enum ComposerMenuAction { model, info }

class ComposerAtAction {
  const ComposerAtAction({
    required this.value,
    required this.label,
    this.enabled = true,
    this.insertText,
  });

  final String value;
  final String label;
  final bool enabled;
  final String? insertText;
}

/// The input composer bar at the bottom of the chat screen.
class ComposerBar extends StatefulWidget {
  const ComposerBar({
    super.key,
    required this.agents,
    this.activeAgent,
    this.leadingActions = const [],
    this.showComposerConfigMenu = true,
    this.activeModelLabel,
    this.slashCommands = const [],
    this.atActions = const [],
    this.onSend,
    this.onAgentSelected,
    this.onAtActionSelected,
    this.onOpenModelSelection,
    this.onShowInfo,
    this.onStop,
    this.isStreaming = false,
  });

  final List<AgentDefinition> agents;
  final AgentDefinition? activeAgent;
  final List<Widget> leadingActions;
  final bool showComposerConfigMenu;
  final String? activeModelLabel;
  final List<String> slashCommands;
  final List<ComposerAtAction> atActions;
  final void Function(String text)? onSend;

  @Deprecated(
    'ComposerBar no longer invokes onAgentSelected from the @ menu. '
    'Use onAtActionSelected instead.',
  )
  final void Function(AgentDefinition agent)? onAgentSelected;

  final void Function(String value)? onAtActionSelected;
  final VoidCallback? onOpenModelSelection;
  final VoidCallback? onShowInfo;
  final VoidCallback? onStop;
  final bool isStreaming;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _spinController;
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _focusNode.addListener(() => setState(() {}));
    _controller.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    final nextHasDraft = _controller.text.trim().isNotEmpty;
    if (_hasDraft == nextHasDraft) return;
    setState(() => _hasDraft = nextHasDraft);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.onSend == null) return;
    widget.onSend!(text);
    _controller.clear();
  }

  void _insertSlashCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    final text = '$trimmed ';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _insertTextAtCursor(String text) {
    if (text.isEmpty) return;
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final nextText = value.text.replaceRange(start, end, text);
    final offset = start + text.length;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _controller.removeListener(_onDraftChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSending = widget.onSend == null;
    final chatColors =
        Theme.of(context).extension<ChatColors>() ?? ChatColors.light;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BricksSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BricksRadius.lg),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? chatColors.composerBorderFocus
                      : chatColors.composerBorder,
                ),
                color: chatColors.composerBackground,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !isSending && !widget.isStreaming,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: chatColors.onMessageAssistant),
                    decoration: InputDecoration(
                      hintText: 'Ask Bricks to create something…',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: chatColors.composerPlaceholder),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(
                        BricksSpacing.md,
                        6,
                        BricksSpacing.md,
                        2,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: BricksSpacing.xs),
                    child: Row(
                      children: [
                        if (widget.leadingActions.isNotEmpty) ...[
                          ...widget.leadingActions.expand(
                            (action) => [
                              action,
                              const SizedBox(width: BricksSpacing.xs),
                            ],
                          ),
                        ],
                        if (widget.slashCommands.isNotEmpty) ...[
                          PopupMenuButton<String>(
                            popUpAnimationStyle:
                                BricksTheme.menuPopupAnimationStyle,
                            tooltip: 'Slash commands',
                            enabled: !widget.isStreaming,
                            onSelected: _insertSlashCommand,
                            itemBuilder: (context) => widget.slashCommands
                                .map(
                                  (command) => PopupMenuItem<String>(
                                    value: command,
                                    child: Text(command),
                                  ),
                                )
                                .toList(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: BricksSpacing.sm,
                                vertical: BricksSpacing.xs,
                              ),
                              child: Text(
                                '/',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: chatColors.composerActionIdle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: BricksSpacing.xs),
                        ],
                        if (widget.atActions.isNotEmpty) ...[
                          PopupMenuButton<String>(
                            popUpAnimationStyle:
                                BricksTheme.menuPopupAnimationStyle,
                            tooltip: 'Mention actions',
                            enabled: !widget.isStreaming,
                            onSelected: (value) {
                              String? insertText;
                              for (final action in widget.atActions) {
                                if (action.value == value) {
                                  insertText = action.insertText;
                                  break;
                                }
                              }
                              if (insertText != null) {
                                _insertTextAtCursor(insertText);
                              }
                              widget.onAtActionSelected?.call(value);
                            },
                            itemBuilder: (context) => widget.atActions
                                .map(
                                  (action) => PopupMenuItem<String>(
                                    value: action.value,
                                    enabled: action.enabled,
                                    child: Text(action.label),
                                  ),
                                )
                                .toList(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: BricksSpacing.sm,
                                vertical: BricksSpacing.xs,
                              ),
                              child: Text(
                                '@',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: chatColors.composerActionIdle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: BricksSpacing.xs),
                        ],
                        if (widget.showComposerConfigMenu)
                          PopupMenuButton<ComposerMenuAction>(
                            popUpAnimationStyle:
                                BricksTheme.menuPopupAnimationStyle,
                            tooltip: 'Composer actions',
                            enabled: !widget.isStreaming,
                            icon: Icon(
                              Icons.tune,
                              color: chatColors.composerActionIdle,
                            ),
                            onSelected: (action) {
                              switch (action) {
                                case ComposerMenuAction.model:
                                  widget.onOpenModelSelection?.call();
                                  break;
                                case ComposerMenuAction.info:
                                  widget.onShowInfo?.call();
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<ComposerMenuAction>(
                                value: ComposerMenuAction.model,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('模型'),
                                    if ((widget.activeModelLabel ?? '')
                                        .isNotEmpty)
                                      Text(
                                        widget.activeModelLabel!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<ComposerMenuAction>(
                                value: ComposerMenuAction.info,
                                child: Text('信息'),
                              ),
                            ],
                          ),
                        const Spacer(),
                        if (widget.isStreaming)
                          RotationTransition(
                            turns: _spinController,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: chatColors.sendActive,
                                foregroundColor: AppColors.backgroundBase,
                              ),
                              onPressed: widget.onStop,
                              icon: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.backgroundBase,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(Icons.stop, size: 16),
                              ),
                              tooltip: 'Stop',
                            ),
                          )
                        else
                          IconButton(
                            onPressed: isSending ? null : _submit,
                            icon: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: _hasDraft
                                        ? chatColors.sendActive
                                        : chatColors.sendIdle,
                                  ),
                            tooltip: 'Send',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
