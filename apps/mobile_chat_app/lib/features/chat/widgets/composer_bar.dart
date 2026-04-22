import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Actions available in the composer popup menu.
enum ComposerMenuAction { newContext, model, agents, info }

/// The input composer bar at the bottom of the chat screen.
class ComposerBar extends StatefulWidget {
  const ComposerBar({
    super.key,
    required this.agents,
    this.activeAgent,
    this.routerAction,
    this.showRouteAtMarker = false,
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

  /// Optional router switch action displayed before composer action buttons.
  final Widget? routerAction;
  final bool showRouteAtMarker;

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
                    decoration: InputDecoration(
                      hintText: 'Ask Bricks to create something…',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(
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
                        if (widget.routerAction != null) ...[
                          widget.routerAction!,
                          const SizedBox(width: BricksSpacing.xs),
                        ],
                        if (widget.showRouteAtMarker) ...[
                          Text(
                            '@',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: BricksSpacing.xs),
                        ],
                        PopupMenuButton<ComposerMenuAction>(
                          popUpAnimationStyle:
                              BricksTheme.menuPopupAnimationStyle,
                          tooltip: 'Composer actions',
                          enabled: !widget.isStreaming,
                          icon: const Icon(Icons.tune),
                          onSelected: (action) {
                            switch (action) {
                              case ComposerMenuAction.newContext:
                                // TODO: implement new context action.
                                break;
                              case ComposerMenuAction.model:
                                widget.onOpenModelSelection?.call();
                                break;
                              case ComposerMenuAction.agents:
                                // TODO: implement agents action.
                                break;
                              case ComposerMenuAction.info:
                                widget.onShowInfo?.call();
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<ComposerMenuAction>(
                              value: ComposerMenuAction.newContext,
                              child: Text('新上下文'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem<ComposerMenuAction>(
                              value: ComposerMenuAction.model,
                              child: Text('模型'),
                            ),
                            PopupMenuItem<ComposerMenuAction>(
                              value: ComposerMenuAction.agents,
                              child: Text('Agents'),
                            ),
                            PopupMenuItem<ComposerMenuAction>(
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
