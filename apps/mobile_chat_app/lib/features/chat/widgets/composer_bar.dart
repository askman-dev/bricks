import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Actions available in the composer popup menu.
enum ComposerMenuAction { model, info }

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
    this.onSend,
    this.onAgentSelected,
    this.onOpenModelSelection,
    this.onShowInfo,
    this.onStop,
    this.isStreaming = false,
  });

  /// Available agents for @mention selection.
  final List<AgentDefinition> agents;

  /// The agent currently selected for replies.
  final AgentDefinition? activeAgent;

  /// Optional actions displayed before composer action buttons.
  final List<Widget> leadingActions;

  /// Whether to show the composer configuration menu.
  final bool showComposerConfigMenu;

  /// Display label for the currently active model.
  final String? activeModelLabel;

  /// Optional slash commands to insert into the input.
  final List<String> slashCommands;

  /// Called when the user submits a message. Null while a send is in progress.
  final void Function(String text)? onSend;

  /// Called when the user picks an agent from the @ menu.
  final void Function(AgentDefinition agent)? onAgentSelected;

  /// Opens runtime model selection UI.
  final VoidCallback? onOpenModelSelection;

  /// Opens debug info dialog.
  final VoidCallback? onShowInfo;

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

  void _insertSlashCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    final text = '$trimmed ';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BricksRadius.lg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    enabled: !isSending && !widget.isStreaming,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: 'Ask Bricks to create something…',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(
                        BricksSpacing.md,
                        BricksSpacing.sm,
                        BricksSpacing.md,
                        BricksSpacing.xs,
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
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: BricksSpacing.sm,
                                vertical: BricksSpacing.xs,
                              ),
                              child: Text(
                                '/',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
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
                            icon: const Icon(Icons.tune),
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
                              onPressed: widget.onStop,
                              icon: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
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
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
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
