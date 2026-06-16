import 'dart:convert';

import '../../services/authenticated_api_client.dart';
import '../settings/llm_config_service.dart';

class NoteSummary {
  const NoteSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.isPublished,
    required this.lineCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String preview;
  final bool isPublished;
  final int lineCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NoteSummary.fromJson(Map<String, dynamic> json) {
    return NoteSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      preview: json['preview'] as String? ?? '',
      isPublished: _parseBool(json['isPublished']),
      lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class NoteDetail {
  const NoteDetail({
    required this.id,
    required this.title,
    required this.body,
    required this.isPublished,
    required this.lineCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final bool isPublished;
  final int lineCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory NoteDetail.fromJson(Map<String, dynamic> json) {
    return NoteDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      isPublished: _parseBool(json['isPublished']),
      lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

class NoteApiService {
  NoteApiService({
    AuthenticatedApiClient? apiClient,
  }) : _apiClient = apiClient ?? AuthenticatedApiClient() {
    _ownsClient = apiClient == null;
  }

  final AuthenticatedApiClient _apiClient;
  late final bool _ownsClient;

  String get _base => LlmConfigService.resolveBaseUrl();

  Uri get _notesUri => Uri.parse('$_base/api/resources/notes');

  Uri _noteUri(String noteId) =>
      Uri.parse('$_base/api/resources/notes/${Uri.encodeComponent(noteId)}');

  Future<List<NoteSummary>> listNotes() async {
    final response = await _apiClient.get(_notesUri);
    if (response.statusCode != 200) {
      throw Exception('Failed to list notes: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['notes'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(NoteSummary.fromJson)
        .toList();
  }

  Future<NoteDetail> getNote(String noteId) async {
    final response = await _apiClient.get(_noteUri(noteId));
    if (response.statusCode != 200) {
      throw Exception('Failed to get note: ${response.statusCode}');
    }
    return NoteDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<NoteDetail> createNote({
    required String title,
    required String body,
    bool isPublished = true,
  }) async {
    final response = await _apiClient.post(
      _notesUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'body': body,
        'isPublished': isPublished,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create note: ${response.statusCode}');
    }
    return NoteDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  void dispose() {
    if (_ownsClient) {
      _apiClient.close();
    }
  }
}
