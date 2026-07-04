enum ChatTaskState { accepted, dispatched, completed, failed, cancelled }

class ChatMediaAttachment {
  const ChatMediaAttachment({
    required this.id,
    required this.kind,
    required this.origin,
    required this.mimeType,
    required this.filename,
    required this.previewUrl,
    required this.contentUrl,
    required this.downloadUrl,
    required this.sizeBytes,
    this.status,
    this.width,
    this.height,
    this.channelRelativePath,
  });

  final String id;
  final String kind;
  final String origin;
  final String mimeType;
  final String filename;
  final String previewUrl;
  final String contentUrl;
  final String downloadUrl;
  final int sizeBytes;
  final String? status;
  final int? width;
  final int? height;
  final String? channelRelativePath;

  Map<String, Object?> toMap() => {
        'id': id,
        'mediaId': id,
        'kind': kind,
        'origin': origin,
        'mimeType': mimeType,
        'filename': filename,
        'previewUrl': previewUrl,
        'contentUrl': contentUrl,
        'downloadUrl': downloadUrl,
        'sizeBytes': sizeBytes,
        if (status != null) 'status': status,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (channelRelativePath != null)
          'channelRelativePath': channelRelativePath,
      };

  static ChatMediaAttachment? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    String? readString(String key) {
      final raw = map[key];
      return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    }

    int? readInt(String key) {
      final raw = map[key];
      return raw is num ? raw.toInt() : null;
    }

    final id = readString('id') ?? readString('mediaId');
    final kind = readString('kind');
    final origin = readString('origin');
    final mimeType = readString('mimeType');
    final filename = readString('filename');
    final previewUrl = readString('previewUrl');
    final contentUrl = readString('contentUrl');
    final downloadUrl = readString('downloadUrl');
    if (id == null ||
        kind == null ||
        origin == null ||
        mimeType == null ||
        filename == null ||
        previewUrl == null ||
        contentUrl == null ||
        downloadUrl == null) {
      return null;
    }
    return ChatMediaAttachment(
      id: id,
      kind: kind,
      origin: origin,
      mimeType: mimeType,
      filename: filename,
      previewUrl: previewUrl,
      contentUrl: contentUrl,
      downloadUrl: downloadUrl,
      sizeBytes: readInt('sizeBytes') ?? 0,
      status: readString('status'),
      width: readInt('width'),
      height: readInt('height'),
      channelRelativePath: readString('channelRelativePath'),
    );
  }
}

enum ChatInvalidationKind {
  chatScopes('chat.scopes'),
  chatChannelNames('chat.channelNames'),
  chatScopeSettings('chat.scopeSettings'),
  resourcesTodoLists('resources.todoLists'),
  resourcesTodos('resources.todos'),
  resourcesTables('resources.tables'),
  resourcesTableColumns('resources.tableColumns'),
  resourcesTableRows('resources.tableRows'),
  resourcesNotes('resources.notes');

  const ChatInvalidationKind(this.value);

  final String value;

  static ChatInvalidationKind? fromValue(Object? value) {
    if (value is! String) return null;
    for (final kind in ChatInvalidationKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}

class ChatInvalidation {
  const ChatInvalidation({
    required this.kind,
    this.channelId,
    this.threadId,
    this.listId,
    this.todoId,
    this.resourceId,
    this.columnKey,
    this.rowId,
    this.noteId,
  });

  final ChatInvalidationKind kind;
  final String? channelId;
  final String? threadId;
  final String? listId;
  final String? todoId;
  final String? resourceId;
  final String? columnKey;
  final String? rowId;
  final String? noteId;

  Map<String, Object?> toMap() => {
        'kind': kind.value,
        if (channelId != null) 'channelId': channelId,
        if (threadId != null) 'threadId': threadId,
        if (listId != null) 'listId': listId,
        if (todoId != null) 'todoId': todoId,
        if (resourceId != null) 'resourceId': resourceId,
        if (columnKey != null) 'columnKey': columnKey,
        if (rowId != null) 'rowId': rowId,
        if (noteId != null) 'noteId': noteId,
      };

  static ChatInvalidation? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final kind = ChatInvalidationKind.fromValue(map['kind']);
    if (kind == null) return null;

    String? readString(String key) {
      final raw = map[key];
      return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    }

    return ChatInvalidation(
      kind: kind,
      channelId: readString('channelId'),
      threadId: readString('threadId'),
      listId: readString('listId'),
      todoId: readString('todoId'),
      resourceId: readString('resourceId'),
      columnKey: readString('columnKey'),
      rowId: readString('rowId'),
      noteId: readString('noteId'),
    );
  }
}

class InputGrammarFixResult {
  const InputGrammarFixResult({
    required this.status,
    this.suggestion,
  });

  final String status;
  final String? suggestion;

  bool get isAccepted => status == 'accepted';
  bool get hasSuggestion =>
      status == 'suggested' && suggestion != null && suggestion!.isNotEmpty;

  Map<String, Object?> toMap() => {
        'status': status,
        'suggestion': suggestion,
      };

  static InputGrammarFixResult? fromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    final status = map['status'];
    if (status != 'accepted' && status != 'suggested') return null;
    final suggestion = map['suggestion'];
    return InputGrammarFixResult(
      status: status as String,
      suggestion: suggestion is String ? suggestion : null,
    );
  }
}

/// A chat message displayed in the [MessageList].
///
/// This is a thin view-model for the chat UI, distinct from
/// the [chat_domain] package's `Message` domain model.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.messageId,
    this.seqId,
    this.writeSeq,
    this.agentId,
    this.agentName,
    this.nodeType,
    this.model,
    DateTime? timestamp,
    this.isStreaming = false,
    this.taskId,
    this.taskState,
    this.idempotencyKey,
    this.createdAt,
    this.acknowledgedAt,
    this.checkpointCursor,
    this.channelId,
    this.sessionId,
    this.threadId,
    this.resolvedBotId,
    this.resolvedSkillId,
    this.arbitrationMode = false,
    this.fallbackToDefaultBot = false,
    this.decisionReason,
    this.traceId,
    this.source,
    this.tieDetected = false,
    this.tieBotIds = const [],
    this.selectedScore,
    this.candidateScoreSummary,
    this.isRecovered = false,
    this.agentLoopPhase,
    this.agentLoopTool,
    this.inputGrammarFix,
    this.invalidations = const [],
    this.mediaAttachments = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  final String role;
  final String content;
  final String? messageId;
  final int? seqId;
  final int? writeSeq;

  final String? agentId;
  final String? agentName;
  final String? nodeType;
  final String? model;
  final DateTime timestamp;
  final bool isStreaming;

  final String? taskId;
  final ChatTaskState? taskState;
  final String? idempotencyKey;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final String? checkpointCursor;

  final String? channelId;
  final String? sessionId;
  final String? threadId;
  final String? resolvedBotId;
  final String? resolvedSkillId;

  final bool arbitrationMode;
  final bool fallbackToDefaultBot;
  final String? decisionReason;
  final String? traceId;
  final String? source;
  final bool tieDetected;
  final List<String> tieBotIds;
  final double? selectedScore;
  final String? candidateScoreSummary;

  final bool isRecovered;

  /// The `agentLoop.phase` value from server metadata.
  /// Present on agent-loop status messages (e.g. `tool_call_start`,
  /// `reasoning`, `step_text`). Null for normal user/assistant messages.
  final String? agentLoopPhase;

  /// The tool name associated with a `tool_call_start` phase message.
  /// Extracted from `agentLoop.toolName` in server metadata.
  final String? agentLoopTool;
  final InputGrammarFixResult? inputGrammarFix;
  final List<ChatInvalidation> invalidations;
  final List<ChatMediaAttachment> mediaAttachments;

  ChatMessage copyWith({
    String? role,
    String? content,
    String? messageId,
    int? seqId,
    int? writeSeq,
    String? agentId,
    String? agentName,
    String? nodeType,
    String? model,
    DateTime? timestamp,
    bool? isStreaming,
    String? taskId,
    ChatTaskState? taskState,
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? acknowledgedAt,
    String? checkpointCursor,
    String? channelId,
    String? sessionId,
    String? threadId,
    String? resolvedBotId,
    String? resolvedSkillId,
    bool? arbitrationMode,
    bool? fallbackToDefaultBot,
    String? decisionReason,
    String? traceId,
    String? source,
    bool? tieDetected,
    List<String>? tieBotIds,
    double? selectedScore,
    String? candidateScoreSummary,
    bool? isRecovered,
    String? agentLoopPhase,
    String? agentLoopTool,
    InputGrammarFixResult? inputGrammarFix,
    List<ChatInvalidation>? invalidations,
    List<ChatMediaAttachment>? mediaAttachments,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      messageId: messageId ?? this.messageId,
      seqId: seqId ?? this.seqId,
      writeSeq: writeSeq ?? this.writeSeq,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      nodeType: nodeType ?? this.nodeType,
      model: model ?? this.model,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      taskId: taskId ?? this.taskId,
      taskState: taskState ?? this.taskState,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      checkpointCursor: checkpointCursor ?? this.checkpointCursor,
      channelId: channelId ?? this.channelId,
      sessionId: sessionId ?? this.sessionId,
      threadId: threadId ?? this.threadId,
      resolvedBotId: resolvedBotId ?? this.resolvedBotId,
      resolvedSkillId: resolvedSkillId ?? this.resolvedSkillId,
      arbitrationMode: arbitrationMode ?? this.arbitrationMode,
      fallbackToDefaultBot: fallbackToDefaultBot ?? this.fallbackToDefaultBot,
      decisionReason: decisionReason ?? this.decisionReason,
      traceId: traceId ?? this.traceId,
      source: source ?? this.source,
      tieDetected: tieDetected ?? this.tieDetected,
      tieBotIds: tieBotIds ?? this.tieBotIds,
      selectedScore: selectedScore ?? this.selectedScore,
      candidateScoreSummary:
          candidateScoreSummary ?? this.candidateScoreSummary,
      isRecovered: isRecovered ?? this.isRecovered,
      agentLoopPhase: agentLoopPhase ?? this.agentLoopPhase,
      agentLoopTool: agentLoopTool ?? this.agentLoopTool,
      inputGrammarFix: inputGrammarFix ?? this.inputGrammarFix,
      invalidations: invalidations ?? this.invalidations,
      mediaAttachments: mediaAttachments ?? this.mediaAttachments,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'role': role,
      'content': content,
      'messageId': messageId,
      'seqId': seqId,
      'writeSeq': writeSeq,
      'agentId': agentId,
      'agentName': agentName,
      'nodeType': nodeType,
      'model': model,
      'timestamp': timestamp.toIso8601String(),
      'isStreaming': isStreaming,
      'taskId': taskId,
      'taskState': taskState?.name,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt?.toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'checkpointCursor': checkpointCursor,
      'channelId': channelId,
      'sessionId': sessionId,
      'threadId': threadId,
      'resolvedBotId': resolvedBotId,
      'resolvedSkillId': resolvedSkillId,
      'arbitrationMode': arbitrationMode,
      'fallbackToDefaultBot': fallbackToDefaultBot,
      'decisionReason': decisionReason,
      'traceId': traceId,
      'source': source,
      'tieDetected': tieDetected,
      'tieBotIds': tieBotIds,
      'selectedScore': selectedScore,
      'candidateScoreSummary': candidateScoreSummary,
      'isRecovered': isRecovered,
      'agentLoopPhase': agentLoopPhase,
      'agentLoopTool': agentLoopTool,
      if (inputGrammarFix != null) 'inputGrammarFix': inputGrammarFix!.toMap(),
      if (invalidations.isNotEmpty)
        'invalidations': invalidations.map((item) => item.toMap()).toList(),
      if (mediaAttachments.isNotEmpty)
        'mediaAttachments':
            mediaAttachments.map((item) => item.toMap()).toList(),
    };
  }

  factory ChatMessage.fromMap(Map<String, Object?> map) {
    ChatTaskState? parseTaskState(Object? value) {
      if (value is! String || value.isEmpty) return null;
      for (final state in ChatTaskState.values) {
        if (state.name == value) return state;
      }
      return null;
    }

    DateTime? parseDate(Object? value) {
      if (value is! String || value.isEmpty) return null;
      final raw = value.trim();
      if (raw.isEmpty) return null;

      final hasTimezone = raw.endsWith('Z') ||
          RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw) ||
          RegExp(r'[+-]\d{4}$').hasMatch(raw);
      final normalized = hasTimezone ? raw : '${raw.replaceFirst(' ', 'T')}Z';
      return DateTime.tryParse(normalized);
    }

    List<ChatInvalidation> parseInvalidations(Object? value) {
      if (value is! List) return const [];
      return value
          .map(ChatInvalidation.fromMap)
          .whereType<ChatInvalidation>()
          .toList(growable: false);
    }

    List<ChatMediaAttachment> parseMediaAttachments(Object? value) {
      if (value is! List) return const [];
      return value
          .map(ChatMediaAttachment.fromMap)
          .whereType<ChatMediaAttachment>()
          .toList(growable: false);
    }

    return ChatMessage(
      role: (map['role'] as String?) ?? 'assistant',
      content: (map['content'] as String?) ?? '',
      messageId: map['messageId'] as String?,
      seqId: (map['seqId'] as num?)?.toInt(),
      writeSeq: (map['writeSeq'] as num?)?.toInt(),
      agentId: map['agentId'] as String?,
      agentName: map['agentName'] as String?,
      nodeType: map['nodeType'] as String?,
      model: map['model'] as String?,
      timestamp: parseDate(map['timestamp']),
      isStreaming: map['isStreaming'] as bool? ?? false,
      taskId: map['taskId'] as String?,
      taskState: parseTaskState(map['taskState']),
      idempotencyKey: map['idempotencyKey'] as String?,
      createdAt: parseDate(map['createdAt']),
      acknowledgedAt: parseDate(map['acknowledgedAt']),
      checkpointCursor: map['checkpointCursor'] as String?,
      channelId: map['channelId'] as String?,
      sessionId: map['sessionId'] as String?,
      threadId: map['threadId'] as String?,
      resolvedBotId: map['resolvedBotId'] as String?,
      resolvedSkillId: map['resolvedSkillId'] as String?,
      arbitrationMode: map['arbitrationMode'] as bool? ?? false,
      fallbackToDefaultBot: map['fallbackToDefaultBot'] as bool? ?? false,
      decisionReason: map['decisionReason'] as String?,
      traceId: map['traceId'] as String?,
      source: map['source'] as String?,
      tieDetected: map['tieDetected'] as bool? ?? false,
      tieBotIds: ((map['tieBotIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toList(),
      selectedScore: (map['selectedScore'] as num?)?.toDouble(),
      candidateScoreSummary: map['candidateScoreSummary'] as String?,
      isRecovered: map['isRecovered'] as bool? ?? false,
      agentLoopPhase: map['agentLoopPhase'] as String?,
      agentLoopTool: map['agentLoopTool'] as String?,
      inputGrammarFix: InputGrammarFixResult.fromMap(map['inputGrammarFix']),
      invalidations: parseInvalidations(map['invalidations']),
      mediaAttachments: parseMediaAttachments(map['mediaAttachments']),
    );
  }
}
