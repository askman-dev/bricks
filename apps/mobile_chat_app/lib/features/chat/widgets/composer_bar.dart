import 'dart:convert';

import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../settings/llm_config_service.dart';
import '../chat_message.dart';

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

class ComposerDraftUpload {
  const ComposerDraftUpload({
    required this.filename,
    required this.mimeType,
    required this.dataBase64,
    required this.isUploading,
    this.errorText,
  });

  final String filename;
  final String mimeType;
  final String dataBase64;
  final bool isUploading;
  final String? errorText;

  bool get hasError => errorText != null && errorText!.trim().isNotEmpty;
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
    this.attachments = const [],
    this.draftUpload,
    this.onSend,
    this.onAttachImage,
    this.onCancelDraftUpload,
    this.onRetryDraftUpload,
    this.onRemoveAttachment,
    this.onAgentSelected,
    this.onAtActionSelected,
    this.onOpenModelSelection,
    this.onShowInfo,
    this.onStop,
    this.isStreaming = false,
    this.backgroundColor,
  });

  final List<AgentDefinition> agents;
  final AgentDefinition? activeAgent;
  final List<Widget> leadingActions;
  final bool showComposerConfigMenu;
  final String? activeModelLabel;
  final List<String> slashCommands;
  final List<ComposerAtAction> atActions;
  final List<ChatMediaAttachment> attachments;
  final ComposerDraftUpload? draftUpload;
  final void Function(String text)? onSend;
  final VoidCallback? onAttachImage;
  final VoidCallback? onCancelDraftUpload;
  final VoidCallback? onRetryDraftUpload;
  final void Function(String mediaId)? onRemoveAttachment;

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
  final Color? backgroundColor;

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
    final nextHasDraft = _controller.text.trim().isNotEmpty ||
        widget.attachments.isNotEmpty ||
        widget.draftUpload != null;
    if (_hasDraft == nextHasDraft) return;
    setState(() => _hasDraft = nextHasDraft);
  }

  @override
  void didUpdateWidget(covariant ComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachments.length != widget.attachments.length ||
        oldWidget.draftUpload != widget.draftUpload) {
      _onDraftChanged();
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if ((text.isEmpty && widget.attachments.isEmpty) ||
        widget.draftUpload != null ||
        widget.onSend == null) {
      return;
    }
    widget.onSend!(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
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
    final hasDraftUpload = widget.draftUpload != null;
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
                  color: chatColors.composerBorder,
                ),
                color: widget.backgroundColor ?? chatColors.composerBackground,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.attachments.isNotEmpty ||
                      widget.draftUpload != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BricksSpacing.sm,
                        BricksSpacing.sm,
                        BricksSpacing.sm,
                        0,
                      ),
                      child: SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.attachments.length +
                              (widget.draftUpload == null ? 0 : 1),
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: BricksSpacing.xs),
                          itemBuilder: (context, index) {
                            final draftUpload = widget.draftUpload;
                            if (draftUpload != null && index == 0) {
                              return _DraftUploadTile(
                                upload: draftUpload,
                                onCancel: widget.onCancelDraftUpload,
                                onRetry: widget.onRetryDraftUpload,
                              );
                            }
                            final attachment = widget.attachments[
                                index - (draftUpload == null ? 0 : 1)];
                            return _PendingAttachmentTile(
                              attachment: attachment,
                              onRemove: widget.onRemoveAttachment == null
                                  ? null
                                  : () => widget.onRemoveAttachment!(
                                        attachment.id,
                                      ),
                            );
                          },
                        ),
                      ),
                    ),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: true,
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
                        IconButton(
                          tooltip: 'Attach image',
                          onPressed:
                              isSending || widget.isStreaming || hasDraftUpload
                                  ? null
                                  : widget.onAttachImage,
                          icon: Icon(
                            Icons.image_outlined,
                            color: chatColors.composerActionIdle,
                          ),
                        ),
                        const SizedBox(width: BricksSpacing.xs),
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
                                    const Text('Model'),
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
                                child: Text('Info'),
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
                            onPressed:
                                isSending || hasDraftUpload ? null : _submit,
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
                                    color: _hasDraft && !hasDraftUpload
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

class _PendingAttachmentTile extends StatelessWidget {
  const _PendingAttachmentTile({
    required this.attachment,
    this.onRemove,
  });

  final ChatMediaAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final chatColors =
        Theme.of(context).extension<ChatColors>() ?? ChatColors.light;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BricksRadius.sm),
              child: _AuthenticatedAttachmentPreview(
                previewUrl: attachment.previewUrl,
                fallback: Container(
                  color: chatColors.composerBackground,
                  child: const Icon(Icons.image, size: 28),
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton.filled(
              tooltip: 'Remove image',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              iconSize: 14,
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftUploadTile extends StatelessWidget {
  const _DraftUploadTile({
    required this.upload,
    this.onCancel,
    this.onRetry,
  });

  final ComposerDraftUpload upload;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final chatColors =
        Theme.of(context).extension<ChatColors>() ?? ChatColors.light;
    final imageBytes = base64Decode(upload.dataBase64);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BricksRadius.sm),
              child: Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: chatColors.composerBackground,
                  child: const Icon(Icons.broken_image_outlined, size: 28),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black
                    .withValues(alpha: upload.hasError ? 0.34 : 0.22),
                borderRadius: BorderRadius.circular(BricksRadius.sm),
              ),
              child: Center(
                child: upload.hasError
                    ? IconButton.filledTonal(
                        tooltip: 'Retry upload',
                        iconSize: 18,
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 36),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                      )
                    : const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton.filled(
              tooltip: 'Remove image',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              iconSize: 14,
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthenticatedAttachmentPreview extends StatelessWidget {
  const _AuthenticatedAttachmentPreview({
    required this.previewUrl,
    required this.fallback,
  });

  final String previewUrl;
  final Widget fallback;

  Uri _mediaUri(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return parsed;
    return Uri.parse('${LlmConfigService.resolveBaseUrl()}$value');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getToken(),
      builder: (context, snapshot) {
        final token = snapshot.data;
        final headers = token == null || token.isEmpty
            ? null
            : {'Authorization': 'Bearer $token'};
        return Image.network(
          _mediaUri(previewUrl).toString(),
          headers: headers,
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        );
      },
    );
  }
}
