import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/llm_config_service.dart';
import 'chat_message.dart';
import 'chat_message_sort.dart';
import 'chat_topology.dart';

class ChatHistorySnapshot {
  const ChatHistorySnapshot({
    required this.messages,
    required this.lastSeqId,
    this.latestCheckpointCursor,
  });

  final List<ChatMessage> messages;
  final int lastSeqId;
  final String? latestCheckpointCursor;
}

class ChatRespondResult {
  const ChatRespondResult({
    required this.text,
    required this.lastSeqId,
    required this.isAsync,
    this.taskState,
  });

  final String text;
  final int lastSeqId;
  final bool isAsync;
  final ChatTaskState? taskState;
}

class ChatPersistedScope {
  const ChatPersistedScope({
    required this.channelId,
    required this.threadId,
    required this.sessionId,
    required this.lastActivityAt,
  });

  final String channelId;
  final String threadId;
  final String sessionId;
  final DateTime? lastActivityAt;
}

class ChatAcceptedTask {
  const ChatAcceptedTask({
    required this.taskId,
    required this.sessionId,
    required this.state,
    required this.acceptedAt,
  });

  final String taskId;
  final String sessionId;
  final String state;
  final String acceptedAt;
}

class ChatChannelNameSetting {
  const ChatChannelNameSetting({
    required this.channelId,
    required this.displayName,
  });

  final String channelId;
  final String displayName;
}

class ChatHistoryApiService {
  ChatHistoryApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsHttpClient;

  http.Client get _client => _httpClient;

  /// Fields from [ChatMessage.toMap] that carry server-relevant information.
  /// UI-only state (isStreaming, arbitration flags, score details, etc.) is
  /// intentionally excluded to keep request payloads and DB storage lean.
  static const _serverMetadataKeys = [
    'resolvedBotId',
    'resolvedSkillId',
    'agentId',
    'agentName',
    'traceId',
  ];

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  String get _base => LlmConfigService.resolveBaseUrl();

  Uri _historyUri(String sessionId, {required int limit}) => Uri.parse(
        '$_base/api/chat/history/${Uri.encodeComponent(sessionId)}?limit=$limit',
      );

  Uri _syncUri(String sessionId, {required int afterSeq}) => Uri.parse(
        '$_base/api/chat/sync/${Uri.encodeComponent(sessionId)}?afterSeq=$afterSeq',
      );

  Uri get _acceptTaskUri => Uri.parse('$_base/api/chat/tasks/accept');

  Uri get _batchMessagesUri => Uri.parse('$_base/api/chat/messages/batch');
  Uri get _scopesUri => Uri.parse('$_base/api/chat/scopes');
  Uri get _scopeSettingsUri => Uri.parse('$_base/api/chat/scope-settings');
  Uri get _channelNamesUri => Uri.parse('$_base/api/chat/channel-names');

  ChatTaskState? _parseTaskState(Object? value) {
    if (value is! String || value.isEmpty) return null;
    for (final state in ChatTaskState.values) {
      if (state.name == value) return state;
    }
    return null;
  }

  Future<List<ChatPersistedScope>> loadScopes({required String token}) async {
    final response = await _client.get(
      _scopesUri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load chat scopes (${response.statusCode})');
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    return ((map['scopes'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ChatPersistedScope(
            channelId: (item['channelId'] as String?) ?? 'default',
            threadId: (item['threadId'] as String?) ?? 'main',
            sessionId: (item['sessionId'] as String?) ?? '',
            lastActivityAt: item['lastActivityAt'] is String
                ? DateTime.tryParse(item['lastActivityAt'] as String)
                : null,
          ),
        )
        .where((scope) => scope.sessionId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ChatScopeSetting>> loadScopeSettings({
    required String token,
  }) async {
    final response = await _client.get(
      _scopeSettingsUri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load chat scope settings (${response.statusCode})',
      );
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    return ((map['settings'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
      final scopeType = chatScopeTypeFromApi(item['scopeType'] as String?);
      if (scopeType == null) {
        throw const FormatException('Invalid scopeType');
      }
      return ChatScopeSetting(
        scopeType: scopeType,
        channelId: (item['channelId'] as String?) ?? 'default',
        threadId: item['threadId'] as String?,
        router: chatRouterFromApi(item['router'] as String?),
        updatedAt: item['updatedAt'] is String
            ? DateTime.tryParse(item['updatedAt'] as String)
            : null,
      );
    }).toList(growable: false);
  }

  Future<List<ChatChannelNameSetting>> loadChannelNames({
    required String token,
  }) async {
    final response = await _client.get(
      _channelNamesUri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load chat channel names (${response.statusCode})',
      );
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    return ((map['channelNames'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => ChatChannelNameSetting(
            channelId: (item['channelId'] as String?) ?? '',
            displayName: (item['displayName'] as String?) ?? '',
          ),
        )
        .where(
          (item) =>
              item.channelId.trim().isNotEmpty &&
              item.displayName.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<ChatHistorySnapshot> load({
    required String token,
    required String sessionId,
    int limit = 100,
  }) async {
    final response = await _client.get(
      _historyUri(sessionId, limit: limit),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load chat history (${response.statusCode})');
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map) {
      return const ChatHistorySnapshot(messages: [], lastSeqId: 0);
    }

    final map = Map<String, dynamic>.from(raw);
    final messages = ((map['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .map(_messageFromServerMap)
        .toList();
    messages.sort(compareChatMessagesByCreatedTime);

    return ChatHistorySnapshot(
      messages: messages,
      lastSeqId: (map['lastSeqId'] as num?)?.toInt() ?? 0,
      latestCheckpointCursor: map['latestCheckpointCursor'] as String?,
    );
  }

  Future<ChatHistorySnapshot> sync({
    required String token,
    required String sessionId,
    required int afterSeq,
  }) async {
    final response = await _client.get(
      _syncUri(sessionId, afterSeq: afterSeq),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to sync chat history (${response.statusCode})');
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map) {
      return ChatHistorySnapshot(messages: const [], lastSeqId: afterSeq);
    }
    final map = Map<String, dynamic>.from(raw);
    final messages = ((map['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .map(_messageFromServerMap)
        .toList();
    messages.sort(compareChatMessagesByCreatedTime);

    return ChatHistorySnapshot(
      messages: messages,
      lastSeqId: (map['lastSeqId'] as num?)?.toInt() ?? afterSeq,
      latestCheckpointCursor: null,
    );
  }

  Future<ChatRespondResult> respond({
    required String token,
    required String taskId,
    required String idempotencyKey,
    required ChatSessionScope scope,
    required String userMessageId,
    required String assistantMessageId,
    required String userMessage,
    String? resolvedBotId,
    String? resolvedSkillId,
    String? provider,
    String? model,
    String? configId,
    DateTime? createdAt,
  }) async {
    final response = await _client.post(
      Uri.parse('$_base/api/chat/respond'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'taskId': taskId,
        'idempotencyKey': idempotencyKey,
        'channelId': scope.channelId,
        'sessionId': scope.sessionId,
        'threadId': scope.threadId,
        'userMessageId': userMessageId,
        'assistantMessageId': assistantMessageId,
        'userMessage': userMessage,
        'resolvedBotId': resolvedBotId,
        'resolvedSkillId': resolvedSkillId,
        'provider': provider,
        'model': model,
        'configId': configId,
        'createdAt': createdAt?.toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to respond chat task (${response.statusCode})');
    }

    final raw = jsonDecode(response.body);
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return ChatRespondResult(
      text: (map['text'] as String?) ?? '',
      lastSeqId: (map['lastSeqId'] as num?)?.toInt() ?? 0,
      isAsync: (map['mode'] as String?) == 'async',
      taskState: _parseTaskState(map['state']),
    );
  }

  Future<void> saveScopeSetting({
    required String token,
    required ChatScopeType scopeType,
    required String channelId,
    String? threadId,
    required ChatRouter? router,
  }) async {
    final response = await _client.put(
      _scopeSettingsUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'scopeType': scopeType.apiValue,
        'channelId': channelId,
        if (threadId != null) 'threadId': threadId,
        'router': router?.apiValue,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to save chat scope setting (${response.statusCode})',
      );
    }
  }

  Future<void> saveChannelName({
    required String token,
    required String channelId,
    String? displayName,
  }) async {
    final response = await _client.put(
      _channelNamesUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'channelId': channelId,
        'displayName': displayName?.trim(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to save chat channel name (${response.statusCode})',
      );
    }
  }

  Future<ChatAcceptedTask> acceptTask({
    required String token,
    required String taskId,
    required String idempotencyKey,
    required ChatSessionScope scope,
    String? resolvedBotId,
    String? resolvedSkillId,
  }) async {
    final response = await _client.post(
      _acceptTaskUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'taskId': taskId,
        'idempotencyKey': idempotencyKey,
        'channelId': scope.channelId,
        'sessionId': scope.sessionId,
        'threadId': scope.threadId,
        'resolvedBotId': resolvedBotId,
        'resolvedSkillId': resolvedSkillId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to accept chat task (${response.statusCode})');
    }

    final raw = jsonDecode(response.body);
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return ChatAcceptedTask(
      taskId: (map['taskId'] as String?) ?? taskId,
      sessionId: (map['sessionId'] as String?) ?? scope.sessionId,
      state: (map['state'] as String?) ?? 'accepted',
      acceptedAt:
          (map['acceptedAt'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  List<ChatMessage> messagesForPersistence(List<ChatMessage> messages) {
    // Do not persist transient empty assistant placeholders while a response is
    // still streaming; otherwise refresh can show an empty bubble with no
    // meaningful content.
    return messages
        .where(
          (message) => !(message.role == 'assistant' &&
              message.isStreaming &&
              message.content.trim().isEmpty),
        )
        .toList(growable: false);
  }

  Future<int> upsertMessages({
    required String token,
    required List<ChatMessage> messages,
  }) async {
    final persistableMessages = messagesForPersistence(messages);
    if (persistableMessages.isEmpty) return 0;

    final response = await _client.put(
      _batchMessagesUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messages': persistableMessages.map(_messageToServerMap).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to upsert messages (${response.statusCode})');
    }
    final raw = jsonDecode(response.body);
    if (raw is! Map) return 0;
    return (raw['lastSeqId'] as num?)?.toInt() ?? 0;
  }

  ChatMessage _messageFromServerMap(Map<String, Object?> map) {
    final metadata = (map['metadata'] is Map)
        ? Map<String, Object?>.from(map['metadata'] as Map)
        : const <String, Object?>{};
    final payload = <String, Object?>{
      ...metadata,
      'messageId': map['messageId'],
      'taskId': map['taskId'],
      'channelId': map['channelId'],
      'sessionId': map['sessionId'],
      'threadId': map['threadId'],
      'role': map['role'],
      'content': map['content'],
      'taskState': map['taskState'],
      'checkpointCursor': map['checkpointCursor'],
      'createdAt': map['createdAt'],
      'timestamp': map['createdAt'],
    };
    return ChatMessage.fromMap(payload);
  }

  Map<String, Object?> _messageToServerMap(ChatMessage message) {
    final map = message.toMap();
    final metadata = <String, Object?>{};
    for (final key in _serverMetadataKeys) {
      final value = map[key];
      if (value != null) metadata[key] = value;
    }
    return {
      'messageId': map['messageId'],
      'taskId': map['taskId'],
      'channelId': map['channelId'],
      'sessionId': map['sessionId'],
      'threadId': map['threadId'],
      'role': map['role'],
      'content': map['content'],
      'taskState': map['taskState'],
      'checkpointCursor': map['checkpointCursor'],
      'createdAt': map['createdAt'],
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}
