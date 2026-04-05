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

class ChatSessionScope {
  const ChatSessionScope({
    required this.channelId,
    required this.threadId,
  });

  final String channelId;
  final String threadId;

  String get sessionId => 'session:$channelId:$threadId';
}

class ChatTopologyResolver {
  const ChatTopologyResolver({this.defaultChannelId = 'default'});

  final String defaultChannelId;

  String resolveChannelId(
      {required List<ChatChannel> channels, String? requestedChannelId}) {
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
