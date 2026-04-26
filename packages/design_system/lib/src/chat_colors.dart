// Flutter dependency – intentionally thin.
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Semantic color tokens for the chat module.
class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors({
    required this.messageUserBackground,
    required this.messageAssistantBackground,
    required this.onMessageUser,
    required this.onMessageAssistant,
    required this.metaText,
    required this.agentName,
    required this.agentBadgeContainer,
    required this.onAgentBadgeContainer,
    required this.agentAccent,
    required this.linkText,
    required this.composerBackground,
    required this.composerBorder,
    required this.composerBorderFocus,
    required this.composerPlaceholder,
    required this.codeBlockBackground,
    required this.quoteBackground,
  });

  final Color messageUserBackground;
  final Color messageAssistantBackground;
  final Color onMessageUser;
  final Color onMessageAssistant;
  final Color metaText;
  final Color agentName;
  final Color agentBadgeContainer;
  final Color onAgentBadgeContainer;
  final Color agentAccent;
  final Color linkText;
  final Color composerBackground;
  final Color composerBorder;
  final Color composerBorderFocus;
  final Color composerPlaceholder;
  final Color codeBlockBackground;
  final Color quoteBackground;

  static const ChatColors light = ChatColors(
    messageUserBackground: Color(0xFFE9EBEC),
    messageAssistantBackground: Colors.transparent,
    onMessageUser: Color(0xFF1F2328),
    onMessageAssistant: Color(0xFF1F2328),
    metaText: Color(0xFF657786),
    agentName: Color(0xFF1D9BF0),
    agentBadgeContainer: Color(0xFFE8EEF2),
    onAgentBadgeContainer: Color(0xFF576470),
    agentAccent: Color(0xFF1D9BF0),
    linkText: Color(0xFF1D9BF0),
    composerBackground: Color(0xFFF5F7F8),
    composerBorder: Color(0xFFD0D5D9),
    composerBorderFocus: Color(0xFF536471),
    composerPlaceholder: Color(0xFF7A838A),
    codeBlockBackground: Color(0xFFEFF3F4),
    quoteBackground: Color(0xFFE8EEF2),
  );

  static const ChatColors dark = ChatColors(
    messageUserBackground: AppColors.surfaceDefault,
    messageAssistantBackground: Colors.transparent,
    onMessageUser: AppColors.textPrimary,
    onMessageAssistant: AppColors.textPrimary,
    metaText: AppColors.textSecondary,
    agentName: AppColors.accentPrimary,
    agentBadgeContainer: AppColors.surfaceSubtle,
    onAgentBadgeContainer: AppColors.textSecondary,
    agentAccent: AppColors.accentPrimary,
    linkText: AppColors.accentPrimary,
    composerBackground: AppColors.surfaceElevated,
    composerBorder: AppColors.borderSubtle,
    composerBorderFocus: AppColors.borderFocus,
    composerPlaceholder: AppColors.textTertiary,
    codeBlockBackground: AppColors.surfaceElevated,
    quoteBackground: AppColors.surfaceSubtle,
  );

  @override
  ChatColors copyWith({
    Color? messageUserBackground,
    Color? messageAssistantBackground,
    Color? onMessageUser,
    Color? onMessageAssistant,
    Color? metaText,
    Color? agentName,
    Color? agentBadgeContainer,
    Color? onAgentBadgeContainer,
    Color? agentAccent,
    Color? linkText,
    Color? composerBackground,
    Color? composerBorder,
    Color? composerBorderFocus,
    Color? composerPlaceholder,
    Color? codeBlockBackground,
    Color? quoteBackground,
  }) {
    return ChatColors(
      messageUserBackground:
          messageUserBackground ?? this.messageUserBackground,
      messageAssistantBackground:
          messageAssistantBackground ?? this.messageAssistantBackground,
      onMessageUser: onMessageUser ?? this.onMessageUser,
      onMessageAssistant: onMessageAssistant ?? this.onMessageAssistant,
      metaText: metaText ?? this.metaText,
      agentName: agentName ?? this.agentName,
      agentBadgeContainer: agentBadgeContainer ?? this.agentBadgeContainer,
      onAgentBadgeContainer:
          onAgentBadgeContainer ?? this.onAgentBadgeContainer,
      agentAccent: agentAccent ?? this.agentAccent,
      linkText: linkText ?? this.linkText,
      composerBackground: composerBackground ?? this.composerBackground,
      composerBorder: composerBorder ?? this.composerBorder,
      composerBorderFocus: composerBorderFocus ?? this.composerBorderFocus,
      composerPlaceholder: composerPlaceholder ?? this.composerPlaceholder,
      codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
      quoteBackground: quoteBackground ?? this.quoteBackground,
    );
  }

  @override
  ChatColors lerp(ChatColors? other, double t) {
    if (other == null) return this;
    return ChatColors(
      messageUserBackground:
          Color.lerp(messageUserBackground, other.messageUserBackground, t)!,
      messageAssistantBackground: Color.lerp(
        messageAssistantBackground,
        other.messageAssistantBackground,
        t,
      )!,
      onMessageUser: Color.lerp(onMessageUser, other.onMessageUser, t)!,
      onMessageAssistant:
          Color.lerp(onMessageAssistant, other.onMessageAssistant, t)!,
      metaText: Color.lerp(metaText, other.metaText, t)!,
      agentName: Color.lerp(agentName, other.agentName, t)!,
      agentBadgeContainer:
          Color.lerp(agentBadgeContainer, other.agentBadgeContainer, t)!,
      onAgentBadgeContainer:
          Color.lerp(onAgentBadgeContainer, other.onAgentBadgeContainer, t)!,
      agentAccent: Color.lerp(agentAccent, other.agentAccent, t)!,
      linkText: Color.lerp(linkText, other.linkText, t)!,
      composerBackground:
          Color.lerp(composerBackground, other.composerBackground, t)!,
      composerBorder: Color.lerp(composerBorder, other.composerBorder, t)!,
      composerBorderFocus:
          Color.lerp(composerBorderFocus, other.composerBorderFocus, t)!,
      composerPlaceholder:
          Color.lerp(composerPlaceholder, other.composerPlaceholder, t)!,
      codeBlockBackground:
          Color.lerp(codeBlockBackground, other.codeBlockBackground, t)!,
      quoteBackground: Color.lerp(quoteBackground, other.quoteBackground, t)!,
    );
  }
}
