// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:indexed_db' as idb;

import 'path_validator.dart';

/// IndexedDB-backed implementation of [AgentsRepository] for web.
///
/// The [agentsPath] argument is ignored on web; persistence is handled
/// entirely within IndexedDB.
class AgentsRepositoryDelegate {
  AgentsRepositoryDelegate(String agentsPath);

  static const _dbName = 'bricks_agents';
  static const _storeName = 'agents';

  Future<idb.Database> _openDb() async {
    final factory = html.window.indexedDB;
    if (factory == null) {
      throw StateError('IndexedDB is not available in this browser.');
    }
    return factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (event) {
        final request = event.target as idb.Request;
        final db = request.result as idb.Database;
        if (!db.objectStoreNames!.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
  }

  Future<List<String>> listAgentNames() async {
    final db = await _openDb();
    final txn = db.transaction(_storeName, 'readonly');
    final store = txn.objectStore(_storeName);
    final keys = await store.getAllKeys();
    await txn.completed;
    return keys.whereType<String>().toList();
  }

  Future<String?> loadAgent(String name) async {
    PathValidator.validateSegment(name, 'name');
    final db = await _openDb();
    final txn = db.transaction(_storeName, 'readonly');
    final store = txn.objectStore(_storeName);
    final value = await store.getObject(name);
    await txn.completed;
    return value as String?;
  }

  Future<void> saveAgent(String name, String content) async {
    PathValidator.validateSegment(name, 'name');
    final db = await _openDb();
    final txn = db.transaction(_storeName, 'readwrite');
    await txn.objectStore(_storeName).put(content, name);
    await txn.completed;
  }

  Future<void> deleteAgent(String name) async {
    PathValidator.validateSegment(name, 'name');
    final db = await _openDb();
    final txn = db.transaction(_storeName, 'readwrite');
    await txn.objectStore(_storeName).delete(name);
    await txn.completed;
  }

  Future<bool> exists(String name) async {
    PathValidator.validateSegment(name, 'name');
    final db = await _openDb();
    final txn = db.transaction(_storeName, 'readonly');
    final store = txn.objectStore(_storeName);
    final value = await store.getObject(name);
    await txn.completed;
    return value != null;
  }
}
