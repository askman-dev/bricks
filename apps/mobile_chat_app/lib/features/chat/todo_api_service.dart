import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/llm_config_service.dart';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.notes,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? notes;
  final bool isCompleted;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class TodoApiService {
  TodoApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  String get _base => LlmConfigService.resolveBaseUrl();
  Uri get _todosUri => Uri.parse('$_base/api/resources/todos');
  Uri _todoUri(String id) => Uri.parse('$_base/api/resources/todos/$id');

  Future<List<TodoItem>> listTodos({
    required String token,
    bool includeCompleted = true,
  }) async {
    final uri = _todosUri.replace(
      queryParameters: {'includeCompleted': includeCompleted.toString()},
    );
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to list todos: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['todos'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TodoItem.fromJson)
        .toList();
  }

  Future<TodoItem> createTodo({
    required String token,
    required String title,
    String? notes,
  }) async {
    final response = await _httpClient.post(
      _todosUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        if (notes != null) 'notes': notes,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create todo: ${response.statusCode}');
    }
    return TodoItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TodoItem> updateTodo({
    required String token,
    required String id,
    String? title,
    String? notes,
    bool? isCompleted,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (notes != null) patch['notes'] = notes;
    if (isCompleted != null) patch['isCompleted'] = isCompleted;

    final response = await _httpClient.patch(
      _todoUri(id),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(patch),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update todo: ${response.statusCode}');
    }
    return TodoItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteTodo({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _todoUri(id),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete todo: ${response.statusCode}');
    }
  }
}
