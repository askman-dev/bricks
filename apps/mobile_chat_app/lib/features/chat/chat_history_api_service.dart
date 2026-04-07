import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/llm_config_service.dart';
import 'chat_message.dart';
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

  Uri _historyUri(String sessionId) =>
      Uri.parse('$_base/api/chat/history/${Uri.encodeComponent(sessionId)}');

  Uri _syncUri(String sessionId, {required int afterSeq}) => Uri.parse(
      '$_base/api/chat/sync/${Uri.encodeComponent(sessionId)}?afterSeq=$afterSeq');

  Uri get _acceptTaskUri => Uri.parse('$_base/api/chat/tasks/accept');

  Uri get _batchMessagesUri => Uri.parse('$_base/api/chat/messages/batch');

  Future<ChatHistorySnapshot> load({
    required String token,
    required String sessionId,
  }) async {
    final response = await _client.get(
      _historyUri(sessionId),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load chat history (${response.statusCode})');
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map) {
      return const ChatHistorySnapshot(messages: [], lastSeqId: 0);
    }

    final map = Map<String, dynamic>.from(raw as Map);
    final messages = ((map['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .map(_messageFromServerMap)
        .toList();

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
    final map = Map<String, dynamic>.from(raw as Map);
    final messages = ((map['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .map(_messageFromServerMap)
        .toList();

    return ChatHistorySnapshot(
      messages: messages,
      lastSeqId: (map['lastSeqId'] as num?)?.toInt() ?? afterSeq,
      latestCheckpointCursor: null,
    );
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

  Future<int> upsertMessages({
    required String token,
    required List<ChatMessage> messages,
  }) async {
    final response = await _client.put(
      _batchMessagesUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messages': messages.map(_messageToServerMap).toList(),
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
