import 'dart:io';
import 'path_validator.dart';

/// IO-backed implementation of [AgentsRepository].
class AgentsRepositoryDelegate {
  AgentsRepositoryDelegate(this._agentsPath);

  final String _agentsPath;

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

  Future<String?> loadAgent(String name) async {
    PathValidator.validateSegment(name, 'name');
    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<void> saveAgent(String name, String content) async {
    PathValidator.validateSegment(name, 'name');
    final dir = Directory(_agentsPath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    await file.writeAsString(content);
  }

  Future<void> deleteAgent(String name) async {
    PathValidator.validateSegment(name, 'name');
    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> exists(String name) async {
    PathValidator.validateSegment(name, 'name');
    final file = File('$_agentsPath${Platform.pathSeparator}$name.md');
    return file.exists();
  }
}
