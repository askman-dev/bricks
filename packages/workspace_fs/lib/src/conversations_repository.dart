import 'dart:convert';
import 'dart:io';
import 'path_validator.dart';

/// Persists and retrieves conversation JSON files within a workspace.
class ConversationsRepository {
  ConversationsRepository({required String workspacePath})
      : _conversationsPath =
            '$workspacePath${Platform.pathSeparator}conversations';

  final String _conversationsPath;

  /// Returns the IDs of all persisted conversations.
  Future<List<String>> listConversationIds() async {
    final dir = Directory(_conversationsPath);
    if (!await dir.exists()) return [];

    final ids = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.path.split(Platform.pathSeparator).last;
        ids.add(filename.replaceAll('.json', ''));
      }
    }
    return ids;
  }

  /// Loads a conversation by [id]. Returns null if not found.
  ///
  /// Throws [ArgumentError] if [id] contains path separators or `..`.
  Future<Map<String, Object?>?> loadConversation(String id) async {
    PathValidator.validateSegment(id, 'id');
    final file = File('$_conversationsPath${Platform.pathSeparator}$id.json');
    if (!await file.exists()) return null;
    final contents = await file.readAsString();
    return jsonDecode(contents) as Map<String, Object?>;
  }

  /// Saves a conversation.
  ///
  /// Throws [ArgumentError] if [id] contains path separators or `..`.
  Future<void> saveConversation(
    String id,
    Map<String, Object?> data,
  ) async {
    PathValidator.validateSegment(id, 'id');
    final dir = Directory(_conversationsPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('$_conversationsPath${Platform.pathSeparator}$id.json');
    await file.writeAsString(jsonEncode(data));
  }
}
