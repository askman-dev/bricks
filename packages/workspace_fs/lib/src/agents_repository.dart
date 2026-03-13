import 'dart:io';
import 'path_validator.dart';

/// Persists and retrieves agent `.md` files within the agents directory.
///
/// Each agent is stored as a single `<name>.md` file.
/// The repository operates on raw file content; callers use
/// [AgentFileCodec] from `chat_domain` to convert to/from
/// [AgentDefinition] objects.
class AgentsRepository {
  AgentsRepository({required String agentsPath}) : _agentsPath = agentsPath;

  final String _agentsPath;

  /// Returns the file names (without extension) of all stored agents.
  Future<List<String>> listAgentNames() async {
    final dir = Directory(_agentsPath);
    if (!await dir.exists()) return [];

    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        final filename = entity.path.split(Platform.pathSeparator).last;
        names.add(filename.replaceAll('.md', ''));
      }
    }
    return names;
  }

  /// Loads the raw `.md` content for the agent with the given [name].
  ///
  /// Returns `null` if the file does not exist.
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<String?> loadAgent(String name) async {
    PathValidator.validateSegment(name, 'name');
    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Saves raw `.md` content for the agent with the given [name].
  ///
  /// Creates the agents directory if it does not exist.
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<void> saveAgent(String name, String content) async {
    PathValidator.validateSegment(name, 'name');
    final dir = Directory(_agentsPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    await file.writeAsString(content);
  }

  /// Deletes the agent file with the given [name].
  ///
  /// Does nothing if the file does not exist.
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<void> deleteAgent(String name) async {
    PathValidator.validateSegment(name, 'name');
    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Returns `true` if an agent file with the given [name] already exists.
  ///
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<bool> exists(String name) async {
    PathValidator.validateSegment(name, 'name');
    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    return file.exists();
  }
}
