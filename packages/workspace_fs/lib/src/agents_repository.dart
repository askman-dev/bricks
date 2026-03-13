import 'agents_repository_io.dart'
    if (dart.library.html) 'agents_repository_web.dart' as impl;

/// Persists and retrieves agent definitions across platforms.
///
/// On native platforms this uses the local filesystem; on Web it falls back
/// to IndexedDB. Callers work with raw `.md` content and use
/// `chat_domain`'s `AgentFileCodec` to convert to/from [AgentDefinition]
/// objects.
class AgentsRepository {
  AgentsRepository({required String agentsPath})
      : _delegate = impl.AgentsRepositoryDelegate(agentsPath);

  final impl.AgentsRepositoryDelegate _delegate;

  /// Returns the file names (without extension) of all stored agents.
  Future<List<String>> listAgentNames() => _delegate.listAgentNames();

  /// Loads the raw `.md` content for the agent with the given [name].
  ///
  /// Returns `null` if the file does not exist.
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<String?> loadAgent(String name) => _delegate.loadAgent(name);

  /// Saves raw `.md` content for the agent with the given [name].
  ///
  /// Creates the agents directory if it does not exist.
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<void> saveAgent(String name, String content) =>
      _delegate.saveAgent(name, content);

  /// Deletes the agent file with the given [name].
  ///
  /// Does nothing if the file does not exist.
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<void> deleteAgent(String name) => _delegate.deleteAgent(name);

  /// Returns `true` if an agent file with the given [name] already exists.
  ///
  /// Throws [ArgumentError] if [name] contains path separators or `..`.
  Future<bool> exists(String name) => _delegate.exists(name);
}
