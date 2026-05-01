enum ChatRouter { defaultRoute, openclaw }

enum ChatScopeType { channel, thread }

extension ChatRouterApi on ChatRouter {
  String get apiValue {
    switch (this) {
      case ChatRouter.defaultRoute:
        return 'default';
      case ChatRouter.openclaw:
        return 'openclaw';
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
    case 'openclaw':
      return ChatRouter.openclaw;
    case 'default':
    default:
      return ChatRouter.defaultRoute;
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
    this.updatedAt,
  });

  final ChatScopeType scopeType;
  final String channelId;
  final String? threadId;
  final ChatRouter router;
  final String? nodeId;
  final String? instructions;
  final DateTime? updatedAt;
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
