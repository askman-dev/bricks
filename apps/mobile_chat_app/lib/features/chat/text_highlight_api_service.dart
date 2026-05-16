import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/llm_config_service.dart';

// ---------------------------------------------------------------------------
// DTO
// ---------------------------------------------------------------------------

class TextHighlight {
  const TextHighlight({
    required this.id,
    required this.messageId,
    required this.selectedText,
    this.startOffset,
    this.endOffset,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String selectedText;
  final int? startOffset;
  final int? endOffset;
  final String color;
  final DateTime createdAt;

  factory TextHighlight.fromJson(Map<String, dynamic> json) {
    return TextHighlight(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      selectedText: json['selectedText'] as String,
      startOffset: (json['startOffset'] as num?)?.toInt(),
      endOffset: (json['endOffset'] as num?)?.toInt(),
      color: json['color'] as String? ?? 'yellow',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class TextHighlightApiService {
  TextHighlightApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  String get _base => LlmConfigService.resolveBaseUrl();
  Uri get _highlightsUri => Uri.parse('$_base/api/resources/highlights');
  Uri _highlightUri(String id) =>
      Uri.parse('$_base/api/resources/highlights/${Uri.encodeComponent(id)}');

  Future<List<TextHighlight>> listHighlights({
    required String token,
    String? messageId,
  }) async {
    final uri = messageId != null
        ? _highlightsUri.replace(queryParameters: {'messageId': messageId})
        : _highlightsUri;
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to list highlights: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['highlights'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TextHighlight.fromJson)
        .toList();
  }

  Future<TextHighlight> createHighlight({
    required String token,
    required String messageId,
    required String selectedText,
    int? startOffset,
    int? endOffset,
    String color = 'yellow',
  }) async {
    final response = await _httpClient.post(
      _highlightsUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messageId': messageId,
        'selectedText': selectedText,
        if (startOffset != null) 'startOffset': startOffset,
        if (endOffset != null) 'endOffset': endOffset,
        'color': color,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create highlight: ${response.statusCode}');
    }
    return TextHighlight.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteHighlight({
    required String token,
    required String id,
  }) async {
    final response = await _httpClient.delete(
      _highlightUri(id),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete highlight: ${response.statusCode}');
    }
  }
}
