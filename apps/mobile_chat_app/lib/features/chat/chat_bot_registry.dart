class ChatSkill {
  const ChatSkill({
    required this.id,
    required this.inputMode,
    required this.outputMode,
    this.isDefault = false,
  });

  final String id;
  final String inputMode;
  final String outputMode;
  final bool isDefault;
}

class ChatBot {
  const ChatBot({
    required this.id,
    required this.displayName,
    required this.defaultSkillId,
    required this.skills,
  });

  final String id;
  final String displayName;
  final String defaultSkillId;
  final List<ChatSkill> skills;
}

class ResolvedChatDispatch {
  const ResolvedChatDispatch({
    required this.bot,
    required this.skillId,
    required this.fallbackToDefaultBot,
    required this.reason,
  });

  final ChatBot bot;
  final String skillId;
  final bool fallbackToDefaultBot;
  final String reason;
}

class ChatBotRegistry {
  ChatBotRegistry({List<ChatBot>? bots, this.defaultBotId = 'ask'})
      : _bots = {
          for (final bot in (bots ?? _defaultBots)) bot.id: bot,
        };

  final Map<String, ChatBot> _bots;
  final String defaultBotId;

  ResolvedChatDispatch resolve({String? requestedBotId}) {
    final defaultBot = _bots[defaultBotId];
    if (defaultBot == null) {
      throw StateError('Default bot "$defaultBotId" is not registered.');
    }

    final requested = requestedBotId == null ? null : _bots[requestedBotId];
    if (requested == null) {
      return _resolveSkillOrFallback(
        defaultBot,
        fallbackToDefaultBot: requestedBotId != null,
        reason: requestedBotId == null
            ? 'No requested bot; routed to default bot.'
            : 'Requested bot "$requestedBotId" is not registered.',
      );
    }

    return _resolveSkillOrFallback(
      requested,
      fallbackToDefaultBot: false,
      reason: 'Resolved requested bot "$requestedBotId".',
    );
  }

  ResolvedChatDispatch _resolveSkillOrFallback(
    ChatBot bot, {
    required bool fallbackToDefaultBot,
    required String reason,
  }) {
    final hasDefaultSkill =
        bot.skills.any((skill) => skill.id == bot.defaultSkillId);
    if (hasDefaultSkill) {
      return ResolvedChatDispatch(
        bot: bot,
        skillId: bot.defaultSkillId,
        fallbackToDefaultBot: fallbackToDefaultBot,
        reason: reason,
      );
    }

    final defaultBot = _bots[defaultBotId]!;
    return ResolvedChatDispatch(
      bot: defaultBot,
      skillId: defaultBot.defaultSkillId,
      fallbackToDefaultBot: true,
      reason:
          'Bot "${bot.id}" missing default skill "${bot.defaultSkillId}"; routed to default bot.',
    );
  }

  static final List<ChatBot> _defaultBots = [
    const ChatBot(
      id: 'ask',
      displayName: 'Ask',
      defaultSkillId: 'ask.default',
      skills: [
        ChatSkill(
          id: 'ask.default',
          inputMode: 'text',
          outputMode: 'text',
          isDefault: true,
        ),
      ],
    ),
    const ChatBot(
      id: 'image_generation',
      displayName: 'Image Generation',
      defaultSkillId: 'image_generation.default',
      skills: [
        ChatSkill(
          id: 'image_generation.default',
          inputMode: 'text',
          outputMode: 'image',
          isDefault: true,
        ),
      ],
    ),
  ];
}
