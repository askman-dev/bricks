// Flutter dependency – intentionally thin.
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Semantic color tokens for the chat module.
class ChatColors extends ThemeExtension<ChatColors> {
  const ChatColors({
    required this.messageUserBackground,
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
    required this.composerActionIdle,
    required this.sendIdle,
    required this.sendActive,
    required this.agentIdentity,
  });

  final Color messageUserBackground;
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
  final Color composerActionIdle;
  final Color sendIdle;
  final Color sendActive;
  final Color agentIdentity;

  static const ChatColors light = ChatColors(
    messageUserBackground: Color(0xFFE9EBEC),
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
    composerPlaceholder: AppColors.textSecondary,
    codeBlockBackground: Color(0xFFEFF3F4),
    quoteBackground: Color(0xFFE8EEF2),
    composerActionIdle: Color(0xFF576470),
    sendIdle: Color(0xFF576470),
    sendActive: Color(0xFF1D9BF0),
    agentIdentity: Color(0xFF1F2328),
  );

  static const ChatColors dark = ChatColors(
    messageUserBackground: Color(0xFFE9EBEC),
    onMessageUser: Color(0xFF1F2328),
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
    composerPlaceholder: AppColors.textPrimary,
    codeBlockBackground: AppColors.surfaceDefault,
    quoteBackground: AppColors.surfaceSubtle,
    composerActionIdle: Color(0xFFB5BDC4),
    sendIdle: Color(0xFFB5BDC4),
    sendActive: Color(0xFFE7E9EA),
    agentIdentity: Color(0xFFDEE3E7),
  );

  @override
  ChatColors copyWith({
    Color? messageUserBackground,
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
    Color? composerActionIdle,
    Color? sendIdle,
    Color? sendActive,
    Color? agentIdentity,
  }) {
    return ChatColors(
      messageUserBackground:
          messageUserBackground ?? this.messageUserBackground,
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
      composerActionIdle: composerActionIdle ?? this.composerActionIdle,
      sendIdle: sendIdle ?? this.sendIdle,
      sendActive: sendActive ?? this.sendActive,
      agentIdentity: agentIdentity ?? this.agentIdentity,
    );
  }

  @override
  ChatColors lerp(ChatColors? other, double t) {
    if (other == null) return this;
    return ChatColors(
      messageUserBackground:
          Color.lerp(messageUserBackground, other.messageUserBackground, t)!,
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
      composerActionIdle:
          Color.lerp(composerActionIdle, other.composerActionIdle, t)!,
      sendIdle: Color.lerp(sendIdle, other.sendIdle, t)!,
      sendActive: Color.lerp(sendActive, other.sendActive, t)!,
      agentIdentity: Color.lerp(agentIdentity, other.agentIdentity, t)!,
    );
  }
}
