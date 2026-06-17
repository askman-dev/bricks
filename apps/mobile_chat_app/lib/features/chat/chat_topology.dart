enum ChatRouter { local, plugin }

enum ChatScopeType { channel, thread }

enum ChatOutputTonePreset { direct, socratic, rhetorical }

extension ChatOutputTonePresetApi on ChatOutputTonePreset {
  String get apiValue {
    switch (this) {
      case ChatOutputTonePreset.direct:
        return 'direct';
      case ChatOutputTonePreset.socratic:
        return 'socratic';
      case ChatOutputTonePreset.rhetorical:
        return 'rhetorical';
    }
  }

  String get label {
    switch (this) {
      case ChatOutputTonePreset.direct:
        return 'Direct';
      case ChatOutputTonePreset.socratic:
        return 'Socratic';
      case ChatOutputTonePreset.rhetorical:
        return 'Rhetorical';
    }
  }
}

class ChatOutputToneSetting {
  const ChatOutputToneSetting.preset(this.preset) : customInstruction = null;

  const ChatOutputToneSetting.custom(this.customInstruction) : preset = null;

  static const direct = ChatOutputToneSetting.preset(
    ChatOutputTonePreset.direct,
  );

  final ChatOutputTonePreset? preset;
  final String? customInstruction;

  bool get isCustom => customInstruction != null;

  Map<String, Object?> toApiMap() {
    final custom = customInstruction?.trim();
    if (custom != null && custom.isNotEmpty) {
      return {
        'type': 'custom',
        'instruction': custom,
      };
    }
    return {
      'type': 'preset',
      'preset': (preset ?? ChatOutputTonePreset.direct).apiValue,
    };
  }
}

extension ChatRouterApi on ChatRouter {
  String get apiValue {
    switch (this) {
      case ChatRouter.local:
        return 'local';
      case ChatRouter.plugin:
        return 'plugin';
    }
  }
}

extension ChatScopeTypeApi on ChatScopeType {
  String get apiValue {
    switch (this) {
      case ChatScopeType.channel:
        return 'channel';
      case ChatScopeType.thread:
        return 'thread';
    }
  }
}

ChatRouter chatRouterFromApi(String? value) {
  switch (value) {
    case 'plugin':
    case 'openclaw':
      return ChatRouter.plugin;
    case 'local':
    case 'default':
    default:
      return ChatRouter.local;
  }
}

ChatScopeType? chatScopeTypeFromApi(String? value) {
  switch (value) {
    case 'channel':
      return ChatScopeType.channel;
    case 'thread':
      return ChatScopeType.thread;
    default:
      return null;
  }
}

ChatOutputTonePreset chatOutputTonePresetFromApi(String? value) {
  switch (value) {
    case 'socratic':
      return ChatOutputTonePreset.socratic;
    case 'rhetorical':
      return ChatOutputTonePreset.rhetorical;
    case 'direct':
    default:
      return ChatOutputTonePreset.direct;
  }
}

ChatOutputToneSetting chatOutputToneFromApi(Object? value) {
  if (value is Map) {
    final map = Map<Object?, Object?>.from(value);
    if (map['type'] == 'custom') {
      final instruction = map['instruction'];
      if (instruction is String && instruction.trim().isNotEmpty) {
        return ChatOutputToneSetting.custom(instruction.trim());
      }
    }
    return ChatOutputToneSetting.preset(
      chatOutputTonePresetFromApi(map['preset'] as String?),
    );
  }
  return ChatOutputToneSetting.direct;
}

class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final bool isDefault;
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.channelId,
    required this.name,
    this.isMain = false,
  });

  final String id;
  final String channelId;
  final String name;
  final bool isMain;
}

class ChatSubSection {
  const ChatSubSection({
    required this.id,
    required this.parentChannelId,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String parentChannelId;
  final String name;
  final DateTime createdAt;
}

class ChatSessionScope {
  const ChatSessionScope({required this.channelId, required this.threadId});

  final String channelId;
  final String threadId;

  String get sessionId => 'session:$channelId:$threadId';
}

class ChatScopeSetting {
  const ChatScopeSetting({
    required this.scopeType,
    required this.channelId,
    required this.router,
    this.nodeId,
    this.threadId,
    this.instructions,
    this.outputTone = ChatOutputToneSetting.direct,
    this.inputGrammarFixerEnabled = false,
    this.resolvedTargetNodeId,
    this.resolvedTargetNodeName,
    this.resolvedTargetPluginId,
    this.updatedAt,
  });

  final ChatScopeType scopeType;
  final String channelId;
  final String? threadId;
  final ChatRouter router;
  final String? nodeId;
  final String? instructions;
  final ChatOutputToneSetting outputTone;
  final bool inputGrammarFixerEnabled;
  final String? resolvedTargetNodeId;
  final String? resolvedTargetNodeName;
  final String? resolvedTargetPluginId;
  final DateTime? updatedAt;
}

/// Sorts [channels] by their latest message time in descending order.
///
/// Channels with a tracked last-message time come before channels with none.
/// When both channels have last-message times, the one with the later time
/// comes first. When neither has a time, the order is deterministic (uses id
/// as a lexicographic tie-breaker).
List<ChatChannel> sortChannelsByLastMessageAt(
  List<ChatChannel> channels,
  Map<String, DateTime> channelLastMessageAt,
) {
  final sorted = [...channels];
  sorted.sort((a, b) {
    final ta = channelLastMessageAt[a.id];
    final tb = channelLastMessageAt[b.id];
    if (ta != null && tb != null) {
      final byLastMessage = tb.compareTo(ta);
      if (byLastMessage != 0) return byLastMessage;
    } else if (tb != null) {
      return 1; // a has no time, b does → b first (more recent)
    } else if (ta != null) {
      return -1; // a has time, b doesn't → a first (more recent)
    }
    // Deterministic tie-breaker: compare ids lexicographically
    return a.id.compareTo(b.id);
  });
  return sorted;
}

List<ChatChannel> applyChannelDisplayNames(
  List<ChatChannel> channels,
  Map<String, String> displayNamesByChannelId,
) {
  if (displayNamesByChannelId.isEmpty) return channels;
  final restoredChannels = channels.map((channel) {
    final displayName = displayNamesByChannelId[channel.id]?.trim();
    if (displayName == null || displayName.isEmpty) return channel;
    return ChatChannel(
      id: channel.id,
      name: displayName,
      isDefault: channel.isDefault,
    );
  }).toList(growable: false);
  final knownChannelIds = restoredChannels.map((item) => item.id).toSet();
  final nameOnlyChannels = displayNamesByChannelId.entries
      .where((entry) => !knownChannelIds.contains(entry.key))
      .where((entry) => entry.value.trim().isNotEmpty)
      .map(
        (entry) => ChatChannel(
          id: entry.key,
          name: entry.value.trim(),
          isDefault: entry.key == 'default',
        ),
      );
  return [...restoredChannels, ...nameOnlyChannels];
}

class ChatTopologyResolver {
  const ChatTopologyResolver({this.defaultChannelId = 'default'});

  final String defaultChannelId;

  String resolveChannelId({
    required List<ChatChannel> channels,
    String? requestedChannelId,
  }) {
    final requested = requestedChannelId;
    if (requested != null &&
        channels.any((channel) => channel.id == requested)) {
      return requested;
    }

    for (final channel in channels) {
      if (channel.isDefault) return channel.id;
    }

    if (channels.any((channel) => channel.id == defaultChannelId)) {
      return defaultChannelId;
    }

    if (channels.isNotEmpty) return channels.first.id;
    return defaultChannelId;
  }
}
