// Flutter dependency – intentionally thin.
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Semantic color tokens for the chat module.
///
/// Business components read these tokens; they never hard-code a color value or
/// branch on [Brightness]. The theme layer is responsible for providing the
/// correct [ChatColors] instance via [ThemeExtension].
///
/// Usage:
/// ```dart
/// final chatColors = Theme.of(context).extension<ChatColors>() ?? ChatColors.light;
/// ```
class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors({
    required this.userMessageContainer,
    required this.onUserMessageContainer,
    required this.userMessageMeta,
    required this.agentName,
    required this.agentBadgeContainer,
    required this.onAgentBadgeContainer,
    required this.agentAccent,
    required this.onAgentMessageContainer,
    required this.agentMessageMeta,
  });

  // ---------------------------------------------------------------------------
  // User message bubble
  // ---------------------------------------------------------------------------

  /// Background color of the user message bubble container.
  final Color userMessageContainer;

  /// Foreground color (text, icons) rendered inside the user message bubble.
  final Color onUserMessageContainer;

  /// Secondary / meta text color inside the user message bubble (timestamp,
  /// thread id, delivery status).
  final Color userMessageMeta;

  // ---------------------------------------------------------------------------
  // Agent (assistant) header & badge
  // ---------------------------------------------------------------------------

  /// Color of the agent name label shown above an assistant message.
  final Color agentName;

  /// Background of the nodeType badge chip shown next to the agent name.
  final Color agentBadgeContainer;

  /// Text color inside the nodeType badge chip.
  final Color onAgentBadgeContainer;

  // ---------------------------------------------------------------------------
  // Agent (assistant) message body
  // ---------------------------------------------------------------------------

  /// Accent color used for the thinking/streaming progress indicator and
  /// arbitration routing labels in agent messages.
  final Color agentAccent;

  /// Main text color of an agent message.
  final Color onAgentMessageContainer;

  /// Secondary / meta text color rendered below an agent message (timestamp,
  /// model name, etc.).
  final Color agentMessageMeta;

  // ---------------------------------------------------------------------------
  // Default instances (used as fallback when no ThemeExtension is registered)
  // ---------------------------------------------------------------------------

  /// Default light-mode chat colors.
  static const ChatColors light = ChatColors(
    userMessageContainer: Color(0xFFF2F2F2),
    onUserMessageContainer: Color(0xFF1C1C1E),
    userMessageMeta: Color(0xFF3A3A3C),
    agentName: Color(0xFF4A90D9),
    agentBadgeContainer: Color(0xFFE5E5EA),
    onAgentBadgeContainer: Color(0xFF636366),
    agentAccent: Color(0xFF4A90D9),
    onAgentMessageContainer: Color(0xFF1C1C1E),
    agentMessageMeta: Color(0xFF8E8E93),
  );

  /// Default dark-mode chat colors.
  static const ChatColors dark = ChatColors(
    userMessageContainer: AppColors.surface2,
    onUserMessageContainer: AppColors.textPrimary,
    userMessageMeta: AppColors.textSecondary,
    agentName: Color(0xFF4A90D9),
    agentBadgeContainer: AppColors.surface3,
    onAgentBadgeContainer: AppColors.textSecondary,
    agentAccent: Color(0xFF4A90D9),
    onAgentMessageContainer: AppColors.textPrimary,
    agentMessageMeta: AppColors.textTertiary,
  );

  // ---------------------------------------------------------------------------
  // ThemeExtension overrides
  // ---------------------------------------------------------------------------

  @override
  ChatColors copyWith({
    Color? userMessageContainer,
    Color? onUserMessageContainer,
    Color? userMessageMeta,
    Color? agentName,
    Color? agentBadgeContainer,
    Color? onAgentBadgeContainer,
    Color? agentAccent,
    Color? onAgentMessageContainer,
    Color? agentMessageMeta,
  }) {
    return ChatColors(
      userMessageContainer: userMessageContainer ?? this.userMessageContainer,
      onUserMessageContainer:
          onUserMessageContainer ?? this.onUserMessageContainer,
      userMessageMeta: userMessageMeta ?? this.userMessageMeta,
      agentName: agentName ?? this.agentName,
      agentBadgeContainer: agentBadgeContainer ?? this.agentBadgeContainer,
      onAgentBadgeContainer:
          onAgentBadgeContainer ?? this.onAgentBadgeContainer,
      agentAccent: agentAccent ?? this.agentAccent,
      onAgentMessageContainer:
          onAgentMessageContainer ?? this.onAgentMessageContainer,
      agentMessageMeta: agentMessageMeta ?? this.agentMessageMeta,
    );
  }

  @override
  ChatColors lerp(ChatColors? other, double t) {
    if (other == null) return this;
    return ChatColors(
      userMessageContainer:
          Color.lerp(userMessageContainer, other.userMessageContainer, t)!,
      onUserMessageContainer:
          Color.lerp(onUserMessageContainer, other.onUserMessageContainer, t)!,
      userMessageMeta:
          Color.lerp(userMessageMeta, other.userMessageMeta, t)!,
      agentName: Color.lerp(agentName, other.agentName, t)!,
      agentBadgeContainer:
          Color.lerp(agentBadgeContainer, other.agentBadgeContainer, t)!,
      onAgentBadgeContainer:
          Color.lerp(onAgentBadgeContainer, other.onAgentBadgeContainer, t)!,
      agentAccent: Color.lerp(agentAccent, other.agentAccent, t)!,
      onAgentMessageContainer:
          Color.lerp(onAgentMessageContainer, other.onAgentMessageContainer, t)!,
      agentMessageMeta:
          Color.lerp(agentMessageMeta, other.agentMessageMeta, t)!,
    );
  }
}
