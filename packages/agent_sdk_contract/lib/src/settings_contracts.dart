/// Settings passed to [AgentClient.createSession].
class AgentSettings {
  const AgentSettings({
    required this.provider,
    required this.model,
    this.systemPrompt,
    this.maxContextTokens = 32768,
    this.maxToolCallsPerTurn = 20,
    this.streamEvents = true,
    this.permissions = const AgentPermissions(),
  });

  final String provider;
  final String model;
  final String? systemPrompt;
  final int maxContextTokens;
  final int maxToolCallsPerTurn;
  final bool streamEvents;
  final AgentPermissions permissions;
}

/// Permission flags for an agent session.
class AgentPermissions {
  const AgentPermissions({
    this.allowFilesystemRead = true,
    this.allowFilesystemWrite = false,
    this.allowNetworkOutbound = false,
    this.allowLocalServer = true,
  });

  final bool allowFilesystemRead;
  final bool allowFilesystemWrite;
  final bool allowNetworkOutbound;
  final bool allowLocalServer;
}
