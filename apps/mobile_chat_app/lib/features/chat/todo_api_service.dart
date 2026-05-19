import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/authenticated_api_client.dart';
import '../settings/llm_config_service.dart';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

class TodoList {
  const TodoList({
    required this.id,
    required this.title,
    this.notes,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String title;
  final String? notes;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Items are only present when fetched via getTodoList (not listTodoLists).
  final List<TodoItem> items;

  factory TodoList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return TodoList(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TodoItem.fromJson)
          .toList(),
    );
  }
}

/// SQLite/Turso stores BOOLEAN as INTEGER (0 = false, non-zero = true).
/// This helper tolerates both [bool] and [int] values from JSON.
bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  return false;
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.isCompleted,
    this.notes,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String title;
  final String? notes;
  final bool isCompleted;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      listId: json['listId'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      isCompleted: _parseBool(json['isCompleted']),
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
  TodoApiService({
    http.Client? httpClient,
    AuthenticatedApiClient? apiClient,
  })  : _apiClient =
            apiClient ?? AuthenticatedApiClient(httpClient: httpClient),
        _ownsApiClient = apiClient == null;

  final AuthenticatedApiClient _apiClient;
  final bool _ownsApiClient;

  void dispose() {
    if (_ownsApiClient) {
      _apiClient.close();
    }
  }

  String get _base => LlmConfigService.resolveBaseUrl();
  Uri get _todoListsUri => Uri.parse('$_base/api/resources/todo-lists');
  Uri _todoListUri(String listId) =>
      Uri.parse('$_base/api/resources/todo-lists/$listId');
  Uri _todosUri(String listId) =>
      Uri.parse('$_base/api/resources/todo-lists/$listId/todos');
  Uri _todoUri(String listId, String id) =>
      Uri.parse('$_base/api/resources/todo-lists/$listId/todos/$id');

  // ---------------------------------------------------------------------------
  // Todo list CRUD
  // ---------------------------------------------------------------------------

  Future<List<TodoList>> listTodoLists() async {
    final response = await _apiClient.get(_todoListsUri);
    if (response.statusCode != 200) {
      throw Exception('Failed to list todo lists: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['lists'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TodoList.fromJson)
        .toList();
  }

  Future<TodoList> getTodoList({
    required String listId,
  }) async {
    final response = await _apiClient.get(_todoListUri(listId));
    if (response.statusCode != 200) {
      throw Exception('Failed to get todo list: ${response.statusCode}');
    }
    return TodoList.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TodoList> createTodoList({
    required String title,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      _todoListsUri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        if (notes != null) 'notes': notes,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create todo list: ${response.statusCode}');
    }
    return TodoList.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TodoList> updateTodoList({
    required String listId,
    String? title,
    String? notes,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (notes != null) patch['notes'] = notes;

    final response = await _apiClient.patch(
      _todoListUri(listId),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(patch),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update todo list: ${response.statusCode}');
    }
    return TodoList.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteTodoList({
    required String listId,
  }) async {
    final response = await _apiClient.delete(_todoListUri(listId));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete todo list: ${response.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // Todo item CRUD (nested under a list)
  // ---------------------------------------------------------------------------

  Future<List<TodoItem>> listTodos({
    required String listId,
    bool includeCompleted = true,
  }) async {
    final uri = _todosUri(listId).replace(
      queryParameters: {'includeCompleted': includeCompleted.toString()},
    );
    final response = await _apiClient.get(uri);
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
    required String listId,
    required String title,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      _todosUri(listId),
      headers: {
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
    required String listId,
    required String id,
    String? title,
    String? notes,
    bool? isCompleted,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (notes != null) patch['notes'] = notes;
    if (isCompleted != null) patch['isCompleted'] = isCompleted;

    final response = await _apiClient.patch(
      _todoUri(listId, id),
      headers: {
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

  /// Convenience wrapper: marks a todo item as completed.
  Future<TodoItem> completeTodo({
    required String listId,
    required String id,
  }) =>
      updateTodo(listId: listId, id: id, isCompleted: true);

  Future<void> deleteTodo({
    required String listId,
    required String id,
  }) async {
    final response = await _apiClient.delete(_todoUri(listId, id));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete todo: ${response.statusCode}');
    }
  }
}
