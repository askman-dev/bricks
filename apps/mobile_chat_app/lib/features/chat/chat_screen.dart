import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:workspace_fs/workspace_fs.dart';

import 'chat_history_api_service.dart';
import 'chat_message_sort.dart';
import 'text_highlight_api_service.dart';

import '../auth/auth_service.dart';
import '../agents/agents_screen.dart';
import '../settings/llm_config_service.dart';
import '../settings/settings_screen.dart';
import '../../services/agents_repository_factory.dart';
import 'asset_table_api_service.dart';
import 'chat_arbitration.dart';
import 'chat_bot_registry.dart';
import 'chat_task_protocol.dart';
import 'chat_topology.dart';
import 'chat_message.dart';
import 'chat_builtin_agents.dart';
import 'chat_navigation_page.dart';
import 'note_api_service.dart';
import 'todo_api_service.dart';
import 'widgets/composer_bar.dart';
import 'widgets/message_list.dart';
import '../../services/authenticated_api_client.dart';

/// The main chat screen – the app's entry point.
///
/// Hosts the [MessageList] and [ComposerBar], and coordinates
/// message sending through the [AgentSession].
///
/// After each user message, enabled [AgentParticipant]s are evaluated for
/// proactive speaking via [ParticipantManager.decideProactiveSpeakers].
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final Set<String> _archivedMessageIds = {};
  bool _isSending = false;
  bool _isStreaming = false;
  bool _isUploadingAttachment = false;
  int _imageUploadGeneration = 0;
  ComposerDraftUpload? _draftUpload;
  final List<ChatMediaAttachment> _pendingMediaAttachments = [];
  bool _loadingAgents = true;
  bool _loadingLlmConfigs = true;
  bool _refreshingScopeTopology = false;
  bool _isDesktopNavigationOpen = false;
  double _desktopNavigationWidth = 260.0;

  static const double _kMinSidebarWidth = 180.0;
  static const double _kMaxSidebarWidth = 480.0;

  /// Manages which agents participate and at what probability.
  final ParticipantManager _participantManager = ParticipantManager();

  final AgentClient _client = AgentCoreClient();
  final ChatBotRegistry _botRegistry = ChatBotRegistry();
  late final ChatArbitrationEngine _arbitrationEngine = ChatArbitrationEngine(
    registry: _botRegistry,
  );
  final ChatTaskProtocol _taskProtocol = ChatTaskProtocol();
  final ChatTopologyResolver _topologyResolver = const ChatTopologyResolver();
  final Map<String, AgentSession> _sessions = {};
  StreamSubscription<AgentSessionEvent>? _currentSubscription;
  List<AgentDefinition> _agents = [];
  AgentDefinition? _activeAgent;
  final LlmConfigService _llmConfigService = LlmConfigService();
  List<LlmConfig> _llmConfigs = const [];
  List<PlatformNodeConfig> _platformNodes = const [];
  Map<String, List<PlatformAgentConfig>> _openClawAgentsByNodeId = const {};
  List<TodoList> _todoLists = const [];
  List<AssetTableSummary> _assetTables = const [];
  List<NoteSummary> _notes = const [];
  final TodoApiService _todoApiService = TodoApiService();
  final AssetTableApiService _assetTableApiService = AssetTableApiService();
  final NoteApiService _noteApiService = NoteApiService();
  String? _sessionConfigSlotId;
  String? _sessionModelOverride;
  String? _authToken;
  final List<ChatChannel> _channels = [
    ChatChannel(id: 'default', name: 'Default Channel', isDefault: true),
  ];
  String _activeChannelId = 'default';
  final Map<String, List<ChatSubSection>> _channelSubSections = {
    'default': <ChatSubSection>[],
  };
  final Map<String, DateTime> _subSectionLastMessageAt = {};
  final Map<String, DateTime> _channelLastMessageAt = {};
  String _activeSubSection = 'main';

  /// Remembers the last-active sub-section id per channel so that switching
  /// back to a previously visited channel restores the correct sub-section.
  final Map<String, String> _lastActiveSubSectionByChannel = {};
  String? _latestCheckpointCursor;
  int _lastSyncedSeq = 0;
  final ChatHistoryApiService _chatHistoryApiService = ChatHistoryApiService();
  final TextHighlightApiService _highlightApiService =
      TextHighlightApiService();
  Map<String, List<HighlightSpan>> _highlights = const {};
  List<TextHighlight> _textHighlights = const [];
  StreamSubscription<ChatHistorySnapshot>? _sseSubscription;
  static const Duration _sseReconnectDelay = Duration(seconds: 3);
  final Map<String, ChatRouter> _channelRouters = {};
  final Map<String, ChatRouter> _threadRouters = {};
  final Map<String, String> _channelNodeIds = {};
  final Map<String, String> _threadNodeIds = {};
  final Map<String, String> _channelInstructions = {};
  final Map<String, String> _threadInstructions = {};
  final Set<String> _topologyRefreshedTaskIds = {};
  int _respondGeneration = 0;
  int _idCounter = 0;

  static const List<String> _openClawSlashCommands = <String>[
    '/help',
    '/commands',
    '/status',
    '/new',
    '/model',
    '/tools',
    '/btw',
  ];
  static const String _createSubSectionMenuValue = '__new__';
  static const String _renameSubSectionMenuValue = '__rename__';
  static const String _archiveSubSectionMenuValue = '__archive__';
  static const String _renameChannelMenuValue = '__channel_rename__';
  static const String _archiveChannelMenuValue = '__channel_archive__';
  static const double _channelMenuMinWidth = 240;
  static const double _channelMenuMaxHeight = 420;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _disconnectSse();
    Timer(const Duration(seconds: 5), _chatHistoryApiService.dispose);
    _todoApiService.dispose();
    _assetTableApiService.dispose();
    _noteApiService.dispose();
    _currentSubscription?.cancel();
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }
    super.dispose();
  }

  Future<void> _loadAgents() async {
    final customDefinitionsFuture = _loadCustomAgentDefinitionsForStartup();
    final llmConfigsFuture = _llmConfigService.fetchConfigs();
    final tokenFuture = AuthService.getToken();

    try {
      final llmConfigs = await llmConfigsFuture;
      final authToken = await tokenFuture;
      final customDefinitions = await customDefinitionsFuture;
      final mergedDefinitions = _mergeWithBuiltInAgents(customDefinitions);
      List<ChatPersistedScope> persistedScopes = const [];
      List<ChatScopeSetting> scopeSettings = const [];
      List<ChatChannelSetting> channels = const [];
      List<PlatformNodeConfig> platformNodes = const [];
      Map<String, List<PlatformAgentConfig>> openClawAgentsByNodeId = const {};
      List<TodoList> todoLists = const [];
      List<AssetTableSummary> assetTables = const [];
      List<NoteSummary> notes = const [];
      try {
        persistedScopes = await _chatHistoryApiService.loadScopes();
      } catch (e) {
        // Scope hydration is best-effort; a backend failure (e.g. 404 during
        // rollout or transient error) must not block the rest of chat setup.
        debugPrint(
          'loadScopes failed, continuing without scope hydration: $e',
        );
      }
      try {
        scopeSettings = await _chatHistoryApiService.loadScopeSettings();
      } catch (e) {
        debugPrint(
          'loadScopeSettings failed, continuing without router hydration: $e',
        );
      }
      try {
        channels = await _chatHistoryApiService.loadChannels();
      } catch (e) {
        debugPrint(
          'loadChannels failed, continuing without channel hydration: $e',
        );
      }
      try {
        platformNodes = await _llmConfigService.fetchPlatformNodes();
        final agentResults = await Future.wait(
          platformNodes.map(
            (node) => _llmConfigService
                .fetchPlatformAgents(
                  nodeId: node.nodeId,
                  sourcePlatform: 'openclaw',
                )
                .then((agents) => MapEntry(node.nodeId, agents)),
          ),
        );
        openClawAgentsByNodeId = Map.fromEntries(agentResults);
      } catch (e) {
        debugPrint(
          'loadOpenClawAgents failed, continuing without OpenClaw @ menu agents: $e',
        );
      }
      try {
        todoLists = await _todoApiService.listTodoLists();
      } catch (e) {
        debugPrint('loadTodoLists failed, continuing without todo lists: $e');
      }
      try {
        assetTables = await _assetTableApiService.listTables();
      } catch (e) {
        debugPrint(
          'loadAssetTables failed, continuing without asset tables: $e',
        );
      }
      try {
        notes = await _noteApiService.listNotes();
      } catch (e) {
        debugPrint('loadNotes failed, continuing without notes: $e');
      }
      final defaultConfig = llmConfigs.firstWhere(
        (cfg) => cfg.isDefault,
        orElse: () => llmConfigs.isNotEmpty
            ? llmConfigs.first
            : const LlmConfig(
                slotId: 'session-default',
                provider: LlmProvider.anthropic,
                baseUrl: '',
                apiKey: '',
                defaultModel: 'claude-sonnet-4-5',
              ),
      );
      if (!mounted) return;
      _syncParticipants(mergedDefinitions);
      final restoredChannels = _hydrateChannelsFromRegistry(channels);
      final restoredSubSections = _hydrateSubSectionsFromRegistry(channels);
      final restoredLastSubSectionByChannel =
          _hydrateLastActiveSubSectionByChannel(
        persistedScopes,
        restoredSubSections,
      );
      final restoredChannelLastMessageAt =
          _hydrateChannelLastMessageAt(persistedScopes);
      final restoredChannelRouters = _hydrateChannelRouters(scopeSettings);
      final restoredThreadRouters = _hydrateThreadRouters(scopeSettings);
      final restoredChannelNodeIds = _hydrateChannelNodeIds(scopeSettings);
      final restoredThreadNodeIds = _hydrateThreadNodeIds(scopeSettings);
      final restoredChannelInstructions =
          _hydrateChannelInstructions(scopeSettings);
      final restoredThreadInstructions =
          _hydrateThreadInstructions(scopeSettings);
      final resolvedActiveChannel = _topologyResolver.resolveChannelId(
        channels: restoredChannels,
        requestedChannelId: _activeChannelId,
      );
      final restoredActiveSubSection =
          restoredLastSubSectionByChannel[resolvedActiveChannel] ?? 'main';
      setState(() {
        _agents = mergedDefinitions;
        _activeAgent ??=
            mergedDefinitions.isNotEmpty ? mergedDefinitions.first : null;
        _loadingAgents = false;
        _llmConfigs = llmConfigs;
        _platformNodes = platformNodes;
        _openClawAgentsByNodeId = openClawAgentsByNodeId;
        _sessionConfigSlotId ??=
            llmConfigs.isNotEmpty ? defaultConfig.slotId : null;
        _sessionModelOverride ??=
            llmConfigs.isNotEmpty ? defaultConfig.defaultModel : null;
        _loadingLlmConfigs = false;
        _authToken = authToken;
        _channels
          ..clear()
          ..addAll(restoredChannels);
        _channelLastMessageAt
          ..clear()
          ..addAll(restoredChannelLastMessageAt);
        _channelSubSections
          ..clear()
          ..addAll(restoredSubSections);
        _lastActiveSubSectionByChannel
          ..clear()
          ..addAll(restoredLastSubSectionByChannel);
        _channelRouters
          ..clear()
          ..addAll(restoredChannelRouters);
        _threadRouters
          ..clear()
          ..addAll(restoredThreadRouters);
        _channelNodeIds
          ..clear()
          ..addAll(restoredChannelNodeIds);
        _threadNodeIds
          ..clear()
          ..addAll(restoredThreadNodeIds);
        _channelInstructions
          ..clear()
          ..addAll(restoredChannelInstructions);
        _threadInstructions
          ..clear()
          ..addAll(restoredThreadInstructions);
        _platformNodes = platformNodes;
        _activeChannelId = resolvedActiveChannel;
        _activeSubSection = restoredActiveSubSection;
        _todoLists = todoLists;
        _assetTables = assetTables;
        _notes = notes;
      });
      await _loadMessagesForActiveScope();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAgents = false;
        _loadingLlmConfigs = false;
        _llmConfigs = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chat setup: $error')),
      );
    }
  }

  Future<void> _refreshResources() async {
    List<TodoList>? todoLists;
    List<AssetTableSummary>? assetTables;
    List<NoteSummary>? notes;

    try {
      todoLists = await _todoApiService.listTodoLists();
    } catch (e) {
      debugPrint('refreshTodoLists failed: $e');
    }
    try {
      assetTables = await _assetTableApiService.listTables();
    } catch (e) {
      debugPrint('refreshAssetTables failed: $e');
    }
    try {
      notes = await _noteApiService.listNotes();
    } catch (e) {
      debugPrint('refreshNotes failed: $e');
    }
    if (!mounted) return;
    setState(() {
      if (todoLists != null) _todoLists = todoLists;
      if (assetTables != null) _assetTables = assetTables;
      if (notes != null) _notes = notes;
    });
  }

  Future<List<AgentDefinition>> _loadCustomAgentDefinitionsForStartup() async {
    try {
      final repo = await createAgentsRepository();
      return _readAgentDefinitions(repo);
    } catch (e) {
      debugPrint(
        'loadCustomAgents failed, continuing with built-in agents only: $e',
      );
      return const [];
    }
  }

  Future<List<AgentDefinition>> _readAgentDefinitions(
    AgentsRepository repository,
  ) async {
    final names = await repository.listAgentNames();
    final definitions = <AgentDefinition>[];
    for (final name in names) {
      final content = await repository.loadAgent(name);
      if (content == null) continue;
      try {
        definitions.add(AgentFileCodec.decode(content));
      } catch (_) {
        // Skip invalid agent files to keep the UI responsive.
      }
    }
    return definitions;
  }

  void _syncParticipants(List<AgentDefinition> definitions) {
    for (final agent in definitions) {
      final exists =
          _participantManager.participants.findById(agent.name) != null;
      if (!exists) {
        _participantManager.addParticipant(
          AgentParticipant(
            agentId: agent.name,
            agentName: agent.name,
            probability: 0.0,
          ),
        );
      }
    }
  }

  List<AgentDefinition> _mergeWithBuiltInAgents(
    List<AgentDefinition> customDefinitions,
  ) {
    final customNames =
        customDefinitions.map((definition) => definition.name).toSet();
    final merged = <AgentDefinition>[];

    for (final builtIn in ChatBuiltInAgents.definitions()) {
      if (!customNames.contains(builtIn.name)) {
        merged.add(builtIn);
      }
    }

    merged.addAll(customDefinitions);
    return List<AgentDefinition>.unmodifiable(merged);
  }

  Future<void> _openAgentsScreen() async {
    final result = await Navigator.of(context).push<AgentDefinition>(
      MaterialPageRoute<AgentDefinition>(
        builder: (_) => const AgentsScreen(),
      ),
    );
    if (result == null || !mounted) return;
    final repo = await createAgentsRepository();
    final customDefinitions = await _readAgentDefinitions(repo);
    final mergedDefinitions = _mergeWithBuiltInAgents(customDefinitions);
    if (!mounted) return;
    setState(() {
      _agents = mergedDefinitions;
      _activeAgent ??=
          mergedDefinitions.isNotEmpty ? mergedDefinitions.first : null;
    });
  }

  void _selectAgent(AgentDefinition agent) {
    setState(() => _activeAgent = agent);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Responding as @${agent.name}')));
  }

  LlmConfig? get _activeLlmConfig {
    final slot = _sessionConfigSlotId;
    if (slot == null) return null;
    for (final config in _llmConfigs) {
      if (config.slotId == slot) return config;
    }
    return null;
  }

  AgentSettings _settingsForAgent(AgentDefinition? agent) {
    final selectedConfig = _activeLlmConfig;
    final selectedModel = _sessionModelOverride ??
        selectedConfig?.defaultModel ??
        _resolveModelId(agent?.model);
    return AgentSettings(
      provider: _providerForConfigOrModel(selectedConfig, selectedModel),
      model: selectedModel,
      systemPrompt: agent?.systemPrompt,
      apiBaseUrl: LlmConfigService.resolveBaseUrl(),
      authToken: _authToken,
      configId: selectedConfig?.id,
      permissions: const AgentPermissions(allowNetworkOutbound: true),
    );
  }

  String _providerForConfigOrModel(LlmConfig? config, String model) {
    if (config != null) {
      switch (config.provider) {
        case LlmProvider.googleAiStudio:
          return 'gemini';
        case LlmProvider.anthropic:
          return 'anthropic';
      }
    }
    return _providerForModel(model);
  }

  String _providerForModel(String model) {
    if (model.startsWith('gemini')) return 'gemini';
    return 'anthropic';
  }

  Future<void> _resetSessions() async {
    await _currentSubscription?.cancel();
    _currentSubscription = null;
    for (final session in _sessions.values) {
      await session.dispose();
    }
    _sessions.clear();
  }

  Future<void> _openRuntimeModelConfigDialog() async {
    if (_llmConfigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No model configuration found')),
      );
      return;
    }

    var selectedSlot = _sessionConfigSlotId ??
        _llmConfigs
            .firstWhere((c) => c.isDefault, orElse: () => _llmConfigs.first)
            .slotId;
    var selectedConfig = _llmConfigs.firstWhere(
      (cfg) => cfg.slotId == selectedSlot,
    );
    var selectedModel = _sessionModelOverride ?? selectedConfig.defaultModel;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            selectedConfig = _llmConfigs.firstWhere(
              (cfg) => cfg.slotId == selectedSlot,
              orElse: () => _llmConfigs.first,
            );
            final models = selectedConfig.models.isNotEmpty
                ? selectedConfig.models
                : <String>[selectedConfig.defaultModel];
            if (!models.contains(selectedModel)) {
              selectedModel = models.first;
            }
            return AlertDialog(
              title: const Text('Session model'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedSlot,
                    decoration: const InputDecoration(
                      labelText: 'Configuration',
                    ),
                    items: _llmConfigs
                        .map(
                          (cfg) => DropdownMenuItem<String>(
                            value: cfg.slotId,
                            child: Text(
                              cfg.isDefault
                                  ? '${cfg.slotId} (default)'
                                  : cfg.slotId,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedSlot = value;
                        final cfg = _llmConfigs.firstWhere(
                          (item) => item.slotId == value,
                          orElse: () => _llmConfigs.first,
                        );
                        selectedModel = cfg.defaultModel;
                      });
                    },
                  ),
                  const SizedBox(height: BricksSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: selectedModel,
                    decoration: const InputDecoration(labelText: 'Model'),
                    items: models
                        .map(
                          (model) => DropdownMenuItem<String>(
                            value: model,
                            child: Text(model),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedModel = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied != true || !mounted) return;
    await _resetSessions();
    if (!mounted) return;
    setState(() {
      _sessionConfigSlotId = selectedSlot;
      _sessionModelOverride = selectedModel;
      _isSending = false;
      _isStreaming = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Session now uses $selectedModel')));
  }

  String _currentComposerModelLabel() {
    if (_effectiveRouterForScope() == ChatRouter.plugin) {
      return 'OpenClaw';
    }
    final selectedConfig = _activeLlmConfig;
    return _sessionModelOverride ??
        selectedConfig?.defaultModel ??
        _resolveModelId(_activeAgent?.model);
  }

  String _resolveModelId(String? model) {
    switch (model) {
      case 'gemini-flash':
        return 'gemini-3-flash-preview';
      case 'gemini-pro':
        return 'gemini-pro';
      case 'haiku':
        return 'claude-haiku-3-5';
      case 'opus':
        return 'claude-opus-4-5';
      case 'sonnet':
      default:
        return model ?? 'claude-sonnet-4-5';
    }
  }

  String _newId(String prefix) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$ms-${_idCounter++}';
  }

  String _timestampName({String prefix = 'channel'}) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '$prefix-${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}-${two(now.minute)}-${two(now.second)}-${three(now.millisecond)}';
  }

  List<ChatChannel> _hydrateChannelsFromRegistry(
    List<ChatChannelSetting> channels,
  ) {
    final channelsById = <String, ChatChannel>{
      'default': const ChatChannel(
        id: 'default',
        name: 'Default Channel',
        isDefault: true,
      ),
    };
    for (final channel in channels) {
      if (channel.scopeType != ChatScopeType.channel) continue;
      if (channel.channelId == 'default') continue;
      channelsById.putIfAbsent(
        channel.channelId,
        () => ChatChannel(
          id: channel.channelId,
          name: channel.displayName,
          isDefault: false,
        ),
      );
    }
    return channelsById.values.toList(growable: false);
  }

  /// Computes the latest message time per channel from persisted scopes.
  ///
  /// For each channel the maximum [ChatPersistedScope.lastActivityAt] across
  /// all of its scopes (sub-sections) is used as the channel's last-message
  /// time.  Scopes with a null [lastActivityAt] are skipped.
  Map<String, DateTime> _hydrateChannelLastMessageAt(
    List<ChatPersistedScope> scopes,
  ) {
    final byChannel = <String, DateTime>{};
    for (final scope in scopes) {
      final at = scope.lastActivityAt;
      if (at == null) continue;
      final current = byChannel[scope.channelId];
      if (current == null || at.isAfter(current)) {
        byChannel[scope.channelId] = at;
      }
    }
    return byChannel;
  }

  Map<String, List<ChatSubSection>> _hydrateSubSectionsFromRegistry(
    List<ChatChannelSetting> channels,
  ) {
    final subSections = <String, List<ChatSubSection>>{
      'default': <ChatSubSection>[],
    };
    for (final channel in channels) {
      final threadId = channel.threadId;
      if (channel.scopeType != ChatScopeType.thread ||
          threadId == null ||
          threadId.trim().isEmpty ||
          threadId == 'main') {
        continue;
      }
      final channelSections = subSections.putIfAbsent(
        channel.channelId,
        () => <ChatSubSection>[],
      );
      if (channelSections.any((item) => item.id == threadId)) {
        continue;
      }
      channelSections.add(
        ChatSubSection(
          id: threadId,
          parentChannelId: channel.channelId,
          name: channel.displayName,
          createdAt: DateTime.now(),
        ),
      );
    }
    return subSections;
  }

  Map<String, String> _hydrateLastActiveSubSectionByChannel(
    List<ChatPersistedScope> scopes,
    Map<String, List<ChatSubSection>> subSectionsByChannel,
  ) {
    final byChannel = <String, ChatPersistedScope>{};
    for (final scope in scopes) {
      if (scope.threadId != 'main') {
        final visibleSections = subSectionsByChannel[scope.channelId];
        final isVisible =
            visibleSections?.any((section) => section.id == scope.threadId) ??
                false;
        if (!isVisible) continue;
      }
      final current = byChannel[scope.channelId];
      final currentAt = current?.lastActivityAt;
      final nextAt = scope.lastActivityAt;
      final shouldReplace = current == null ||
          (nextAt != null && (currentAt == null || nextAt.isAfter(currentAt)));
      if (shouldReplace) byChannel[scope.channelId] = scope;
    }

    return byChannel.map((channelId, scope) {
      return MapEntry(channelId, scope.threadId);
    });
  }

  Map<String, ChatRouter> _hydrateChannelRouters(
    List<ChatScopeSetting> settings,
  ) {
    final routers = <String, ChatRouter>{};
    for (final setting in settings) {
      if (setting.scopeType != ChatScopeType.channel) continue;
      routers[setting.channelId] = setting.router;
    }
    return routers;
  }

  Map<String, ChatRouter> _hydrateThreadRouters(
    List<ChatScopeSetting> settings,
  ) {
    final routers = <String, ChatRouter>{};
    for (final setting in settings) {
      if (setting.scopeType != ChatScopeType.thread ||
          setting.threadId == null) {
        continue;
      }
      if (!_isThreadConversation(threadId: setting.threadId)) {
        continue;
      }
      routers[_subSectionKey(setting.channelId, setting.threadId!)] =
          setting.router;
    }
    return routers;
  }

  Map<String, String> _hydrateChannelNodeIds(List<ChatScopeSetting> settings) {
    final nodeIds = <String, String>{};
    for (final setting in settings) {
      if (setting.scopeType != ChatScopeType.channel) continue;
      final nodeId = setting.nodeId?.trim();
      if (nodeId == null || nodeId.isEmpty) continue;
      nodeIds[setting.channelId] = nodeId;
    }
    return nodeIds;
  }

  Map<String, String> _hydrateThreadNodeIds(List<ChatScopeSetting> settings) {
    final nodeIds = <String, String>{};
    for (final setting in settings) {
      if (setting.scopeType != ChatScopeType.thread ||
          setting.threadId == null) {
        continue;
      }
      final nodeId = setting.nodeId?.trim();
      if (nodeId == null || nodeId.isEmpty) continue;
      if (!_isThreadConversation(threadId: setting.threadId)) {
        continue;
      }
      nodeIds[_subSectionKey(setting.channelId, setting.threadId!)] = nodeId;
    }
    return nodeIds;
  }

  Map<String, String> _hydrateChannelInstructions(
    List<ChatScopeSetting> settings,
  ) {
    final instructions = <String, String>{};
    for (final setting in settings) {
      if (setting.scopeType != ChatScopeType.channel) continue;
      final value = setting.instructions?.trim();
      if (value == null || value.isEmpty) continue;
      instructions[setting.channelId] = value;
    }
    return instructions;
  }

  Map<String, String> _hydrateThreadInstructions(
    List<ChatScopeSetting> settings,
  ) {
    final instructions = <String, String>{};
    for (final setting in settings) {
      if (setting.scopeType != ChatScopeType.thread ||
          setting.threadId == null) {
        continue;
      }
      if (!_isThreadConversation(threadId: setting.threadId)) continue;
      final value = setting.instructions?.trim();
      if (value == null || value.isEmpty) continue;
      instructions[_subSectionKey(setting.channelId, setting.threadId!)] =
          value;
    }
    return instructions;
  }

  void _createChannel() {
    final existingNames =
        _channels.map((item) => item.name.trim().toLowerCase()).toSet();
    _promptChannelName(
      title: 'New Channel',
      confirmLabel: 'Create',
      existingNames: existingNames,
      onConfirmed: (name) {
        final id = _newId('channel');
        final channel = ChatChannel(id: id, name: name, isDefault: false);
        setState(() {
          _channels.add(channel);
          _channelSubSections[id] = <ChatSubSection>[];
          _activeChannelId = id;
          _activeSubSection = 'main';
          _messages.clear();
          _archivedMessageIds.clear();
          _latestCheckpointCursor = null;
          _lastSyncedSeq = 0;
        });
        _configureActiveScopeSync();
        unawaited(
          _chatHistoryApiService
              .saveChannel(
            channelId: id,
            displayName: name,
          )
              .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Failed to save channel name "$id": $error');
          }),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('Created channel: ${channel.name}')),
        );
      },
    );
  }

  void _renameChannel(String channelId) {
    ChatChannel? channel;
    for (final item in _channels) {
      if (item.id == channelId) {
        channel = item;
        break;
      }
    }
    if (channel == null || channel.isDefault) return;
    final existingChannel = channel;
    final existingNames = _channels
        .where((item) => item.id != channelId)
        .map((item) => item.name.trim().toLowerCase())
        .toSet();
    _promptChannelName(
      title: 'Rename Channel',
      confirmLabel: 'Save',
      initialValue: existingChannel.name,
      existingNames: existingNames,
      fieldLabel: 'Channel name',
      hintText: 'Enter a channel name',
      emptyError: 'Channel name is required',
      duplicateError: 'Channel name already exists',
      onConfirmed: (name) {
        setState(() {
          final index = _channels.indexWhere((item) => item.id == channelId);
          if (index < 0) return;
          _channels[index] = ChatChannel(
            id: existingChannel.id,
            name: name,
            isDefault: existingChannel.isDefault,
          );
        });
        unawaited(
          _chatHistoryApiService
              .saveChannel(
            channelId: channelId,
            displayName: name,
          )
              .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Failed to save channel name "$channelId": $error');
          }),
        );
      },
    );
  }

  void _archiveChannel(String channelId) {
    ChatChannel? channel;
    for (final item in _channels) {
      if (item.id == channelId) {
        channel = item;
        break;
      }
    }
    if (channel == null || channel.isDefault) return;
    final wasActive = _activeChannelId == channelId;
    setState(() {
      _channels.removeWhere((item) => item.id == channelId);
      _channelSubSections.remove(channelId);
      _channelLastMessageAt.remove(channelId);
      _lastActiveSubSectionByChannel.remove(channelId);
      _subSectionLastMessageAt.removeWhere(
        (key, value) => key.startsWith('$channelId::'),
      );
      if (wasActive) {
        _activeChannelId = _topologyResolver.resolveChannelId(
          channels: _channels,
          requestedChannelId: null,
        );
        _activeSubSection = 'main';
      }
    });
    if (wasActive) {
      unawaited(_loadMessagesForActiveScope());
    }
    unawaited(
      _chatHistoryApiService
          .archiveChannel(
        channelId: channelId,
        displayName: channel.name,
      )
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to archive channel "$channelId": $error');
      }),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archived channel: ${channel.name}')),
    );
  }

  Future<void> _promptChannelName({
    required String title,
    required String confirmLabel,
    required Set<String> existingNames,
    required ValueChanged<String> onConfirmed,
    String initialValue = '',
    String fieldLabel = 'Channel name',
    String hintText = 'Enter a channel name',
    String emptyError = 'Channel name is required',
    String duplicateError = 'Channel name already exists',
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? errorText;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: fieldLabel,
              hintText: hintText,
              errorText: errorText,
            ),
            onSubmitted: (_) {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) {
                setDialogState(() => errorText = emptyError);
                return;
              }
              if (existingNames.contains(trimmed.toLowerCase())) {
                setDialogState(() => errorText = duplicateError);
                return;
              }
              Navigator.of(dialogContext).pop(trimmed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => errorText = emptyError);
                  return;
                }
                if (existingNames.contains(trimmed.toLowerCase())) {
                  setDialogState(() => errorText = duplicateError);
                  return;
                }
                Navigator.of(dialogContext).pop(trimmed);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    controller.dispose();
    if (!mounted || name == null) return;
    onConfirmed(name);
  }

  void _switchChannel(String channelId) {
    final resolvedChannelId = _topologyResolver.resolveChannelId(
      channels: _channels,
      requestedChannelId: channelId,
    );
    if (_activeChannelId == resolvedChannelId) {
      // Drawer closing is handled by ChatNavigationPage; avoid an extra pop
      // here, which can dismiss the chat route itself.
      return;
    }
    // Persist current sub-section so we can restore it if the user returns.
    _lastActiveSubSectionByChannel[_activeChannelId] = _activeSubSection;
    // Restore last-visited sub-section for the target channel, falling back to
    // 'main' if the remembered section no longer exists in the section list.
    final remembered = _lastActiveSubSectionByChannel[resolvedChannelId];
    final sections = _channelSubSections[resolvedChannelId] ?? const [];
    final restoredSubSection =
        (remembered != null && sections.any((s) => s.id == remembered))
            ? remembered
            : 'main';
    _disconnectSse();
    setState(() {
      _activeChannelId = resolvedChannelId;
      _activeSubSection = restoredSubSection;
      _messages.clear();
      _archivedMessageIds.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    unawaited(_loadMessagesForActiveScope());
  }

  List<ChatSubSection> get _activeSubSections {
    final items = _channelSubSections[_activeChannelId] ?? const [];
    final sorted = [...items];
    sorted.sort((a, b) {
      final ta =
          _subSectionLastMessageAt[_subSectionKey(a.parentChannelId, a.id)];
      final tb =
          _subSectionLastMessageAt[_subSectionKey(b.parentChannelId, b.id)];
      if (ta != null && tb != null) {
        final byLastMessage = tb.compareTo(ta);
        if (byLastMessage != 0) return byLastMessage;
      } else if (tb != null) {
        return 1;
      } else if (ta != null) {
        return -1;
      }
      final byCreatedAt = b.createdAt.compareTo(a.createdAt);
      if (byCreatedAt != 0) return byCreatedAt;
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  /// Returns channels sorted by their latest message time in descending order.
  ///
  /// Channels with a tracked last-message time appear before channels with
  /// none.  When all times are equal (or absent) the order is deterministic
  /// via an id-based tie-breaker.
  List<ChatChannel> get _sortedChannels =>
      sortChannelsByLastMessageAt(_channels, _channelLastMessageAt);

  ChatSessionScope get _activeScope => ChatSessionScope(
        channelId: _activeChannelId,
        threadId: _activeSubSection,
      );

  String get _sessionIdForScope => _activeScope.sessionId;

  Future<void> _loadMessagesForActiveScope() async {
    // Capture scope identity before the async gap so we can discard stale
    // responses if the user navigates away while the request is in-flight.
    // capturedSessionId encodes both channelId and subSection, so a single
    // comparison is enough to detect any scope change.
    final capturedChannelId = _activeChannelId;
    final capturedSubSection = _activeSubSection;
    final capturedSessionId = _sessionIdForScope;
    _disconnectSse();

    bool _isScopeStale() => _sessionIdForScope != capturedSessionId;

    try {
      final snapshot = await _chatHistoryApiService.load(
        sessionId: capturedSessionId,
      );
      if (!mounted || _isScopeStale()) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(snapshot.messages);
        _latestCheckpointCursor = snapshot.latestCheckpointCursor;
        _lastSyncedSeq = snapshot.lastSeqId;
      });
      _updateSubSectionLastMessageAtFromMessages(
        channelId: capturedChannelId,
        subSection: capturedSubSection,
      );
      _configureActiveScopeSync();
      unawaited(_loadHighlightsForMessages());
    } catch (_) {
      if (!mounted || _isScopeStale()) return;
      setState(() {
        _messages.clear();
        _archivedMessageIds.clear();
        _highlights = const {};
        _textHighlights = const [];
        _latestCheckpointCursor = null;
        _lastSyncedSeq = 0;
      });
      _configureActiveScopeSync();
    }
  }

  /// Loads all highlights for the currently loaded messages and refreshes
  /// the [_highlights] map so [MessageList] can render them.
  Future<void> _loadHighlightsForMessages() async {
    try {
      final list = await _highlightApiService.listHighlights();
      if (!mounted) return;
      final updated = <String, List<HighlightSpan>>{};
      for (final h in list) {
        updated.putIfAbsent(h.messageId, () => []).add(
              HighlightSpan.fromHighlight(h),
            );
      }
      setState(() {
        _highlights = updated;
        _textHighlights = list;
      });
    } catch (e) {
      debugPrint('loadHighlights failed: $e');
    }
  }

  /// Called when the user taps Highlight in the selection context menu.
  Future<void> _handleHighlight(
    String messageId,
    String selectedText,
    int? startOffset,
    int? endOffset,
  ) async {
    try {
      final created = await _highlightApiService.createHighlight(
        messageId: messageId,
        selectedText: selectedText,
        startOffset: startOffset,
        endOffset: endOffset,
      );
      if (!mounted) return;
      setState(() {
        _highlights = {
          ..._highlights,
          messageId: [
            ...(_highlights[messageId] ?? []),
            HighlightSpan.fromHighlight(created),
          ],
        };
        _textHighlights = [..._textHighlights, created];
      });
    } catch (e) {
      debugPrint('createHighlight failed: $e');
      if (!mounted) return;
      final message = switch (e) {
        MissingAuthTokenException() => 'Missing auth token',
        UnauthorizedApiException() => 'Authentication expired',
        _ => 'Failed to create highlight',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Called when the user taps Remove highlight in the floating highlight menu.
  Future<void> _handleDeleteHighlight(String highlightId) async {
    try {
      await _highlightApiService.deleteHighlight(id: highlightId);
      if (!mounted) return;
      setState(() {
        _highlights = {
          for (final entry in _highlights.entries)
            entry.key:
                entry.value.where((h) => h.highlightId != highlightId).toList(),
        }..removeWhere((_, v) => v.isEmpty);
        _textHighlights =
            _textHighlights.where((h) => h.id != highlightId).toList();
      });
    } catch (e) {
      debugPrint('deleteHighlight failed: $e');
      if (!mounted) return;
      final message = switch (e) {
        MissingAuthTokenException() => 'Missing auth token',
        UnauthorizedApiException() => 'Authentication expired',
        _ => 'Failed to delete highlight',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _handleArchiveRound(ChatMessage message) {
    final messageId = message.messageId;
    if (messageId == null) return;
    // Find the user message that immediately precedes this assistant message.
    String? precedingUserMessageId;
    bool foundTarget = false;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (!foundTarget) {
        if (msg.messageId == messageId) foundTarget = true;
      } else if (msg.role == 'user') {
        precedingUserMessageId = msg.messageId;
        break;
      }
    }
    setState(() {
      _archivedMessageIds.add(messageId);
      if (precedingUserMessageId != null) {
        _archivedMessageIds.add(precedingUserMessageId);
      }
    });
  }

  void _handleArchiveReply(ChatMessage message) {
    final messageId = message.messageId;
    if (messageId == null) return;
    setState(() {
      _archivedMessageIds.add(messageId);
    });
  }

  Future<void> _handleFork(ChatMessage message) async {
    final messageId = message.messageId;
    if (messageId == null) return;
    final parentSessionId = _sessionIdForScope;
    final newThreadId = _newId('fork');
    try {
      await _chatHistoryApiService.forkThread(
        parentSessionId: parentSessionId,
        forkMessageId: messageId,
        newThreadId: newThreadId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fork failed: $e')),
      );
      return;
    }
    if (!mounted) return;
    final section = ChatSubSection(
      id: newThreadId,
      parentChannelId: _activeChannelId,
      name: _timestampName(prefix: 'fork'),
      createdAt: DateTime.now(),
    );
    setState(() {
      final items = _channelSubSections.putIfAbsent(
        _activeChannelId,
        () => <ChatSubSection>[],
      );
      items.add(section);
      _activeSubSection = newThreadId;
      _lastActiveSubSectionByChannel[_activeChannelId] = newThreadId;
      _messages.clear();
      _archivedMessageIds.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    _configureActiveScopeSync();
    unawaited(
      _chatHistoryApiService
          .saveChannel(
        channelId: _activeChannelId,
        threadId: section.id,
        displayName: section.name,
      )
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to save subsection "${section.id}": $error');
      }),
    );
  }

  Future<void> _handleBranch(ChatMessage message) async {
    // Branch forks from the user message itself — the new thread inherits
    // context up to and including this user message from the parent.
    await _handleFork(message);
  }

  void _handleResend(ChatMessage message) {
    if (message.content.trim().isEmpty) return;
    _sendMessage(message.content);
  }

  String _subSectionKey(String channelId, String sectionId) =>
      '$channelId::$sectionId';

  ChatRouter? _explicitThreadRouter({String? channelId, String? threadId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedThreadId = threadId ?? _activeSubSection;
    if (!_isThreadConversation(threadId: resolvedThreadId)) return null;
    return _threadRouters[_subSectionKey(resolvedChannelId, resolvedThreadId)];
  }

  bool _isKnownPlatformNodeId(String? nodeId) {
    final normalized = _normalizeNodeId(nodeId);
    if (normalized == null) return false;
    for (final node in _platformNodes) {
      if (_normalizeNodeId(node.nodeId) == normalized) return true;
    }
    return false;
  }

  ChatRouter _effectiveChannelRouter({String? channelId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final router = _channelRouters[resolvedChannelId] ?? ChatRouter.local;
    if (router != ChatRouter.plugin) return router;
    return _isKnownPlatformNodeId(_channelNodeIds[resolvedChannelId])
        ? ChatRouter.plugin
        : ChatRouter.local;
  }

  ChatRouter? _effectiveExplicitThreadRouter({
    String? channelId,
    String? threadId,
  }) {
    final router = _explicitThreadRouter(
      channelId: channelId,
      threadId: threadId,
    );
    if (router != ChatRouter.plugin) return router;
    return _isKnownPlatformNodeId(
      _explicitThreadNodeId(
        channelId: channelId,
        threadId: threadId,
      ),
    )
        ? ChatRouter.plugin
        : ChatRouter.local;
  }

  ChatRouter _effectiveRouterForScope({String? channelId, String? threadId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedThreadId = threadId ?? _activeSubSection;
    return _effectiveExplicitThreadRouter(
          channelId: resolvedChannelId,
          threadId: resolvedThreadId,
        ) ??
        _effectiveChannelRouter(channelId: resolvedChannelId);
  }

  String? _explicitThreadNodeId({String? channelId, String? threadId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedThreadId = threadId ?? _activeSubSection;
    if (!_isThreadConversation(threadId: resolvedThreadId)) return null;
    return _threadNodeIds[_subSectionKey(resolvedChannelId, resolvedThreadId)];
  }

  String? _effectiveNodeIdForScope({String? channelId, String? threadId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedThreadId = threadId ?? _activeSubSection;
    if (_effectiveRouterForScope(
          channelId: resolvedChannelId,
          threadId: resolvedThreadId,
        ) !=
        ChatRouter.plugin) {
      return null;
    }
    if (_effectiveExplicitThreadRouter(
          channelId: resolvedChannelId,
          threadId: resolvedThreadId,
        ) ==
        ChatRouter.plugin) {
      return _normalizeNodeId(
        _explicitThreadNodeId(
          channelId: resolvedChannelId,
          threadId: resolvedThreadId,
        ),
      );
    }
    return _normalizeNodeId(_channelNodeIds[resolvedChannelId]);
  }

  String? _normalizeNodeId(String? nodeId) {
    final trimmed = nodeId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _platformNodeLabel(PlatformNodeConfig node) {
    final trimmed = node.displayName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return _normalizeNodeId(node.nodeId) ?? 'OpenClaw';
  }

  String _nodeLabel(String? nodeId) {
    final trimmed = _normalizeNodeId(nodeId);
    if (trimmed == null) return 'OpenClaw';
    for (final node in _platformNodes) {
      if (_normalizeNodeId(node.nodeId) == trimmed) {
        return _platformNodeLabel(node);
      }
    }
    return 'OpenClaw';
  }

  String _routerLabel(ChatRouter router) {
    switch (router) {
      case ChatRouter.local:
        return 'Bricks Default';
      case ChatRouter.plugin:
        return 'OpenClaw';
    }
  }

  PlatformNodeConfig? _activeOpenClawNode() {
    if (_platformNodes.isEmpty) return null;
    return _platformNodes.first;
  }

  List<ComposerAtAction> _composerAtActions(ChatRouter router) {
    if (router == ChatRouter.plugin) {
      final node = _activeOpenClawNode();
      if (node == null) {
        return const <ComposerAtAction>[
          ComposerAtAction(
            value: '__openclaw_no_node__',
            label: 'No OpenClaw node',
            enabled: false,
          ),
        ];
      }
      final agents = _openClawAgentsByNodeId[node.nodeId] ?? const [];
      if (agents.isEmpty) {
        return const <ComposerAtAction>[
          ComposerAtAction(
            value: '__openclaw_no_agents__',
            label: 'No OpenClaw agents',
            enabled: false,
          ),
        ];
      }
      return agents
          .map(
            (agent) => ComposerAtAction(
              value: 'openclaw:${node.nodeId}:${agent.agentId}',
              label: agent.displayName,
              insertText: '@${agent.agentId} ',
            ),
          )
          .toList();
    }
    if (router == ChatRouter.local) {
      return _agents
          .map(
            (agent) => ComposerAtAction(
              value: agent.name,
              label: agent.name,
            ),
          )
          .toList();
    }
    return const <ComposerAtAction>[];
  }

  void _handleComposerAtSelection(ChatRouter router, String value) {
    if (router == ChatRouter.plugin) {
      if (!value.startsWith('openclaw:')) return;
      final node = _activeOpenClawNode();
      if (node == null) return;
      final parts = value.split(':');
      if (parts.length < 3 || parts[1] != node.nodeId) return;
      final agentId = parts.sublist(2).join(':');
      final agents = _openClawAgentsByNodeId[node.nodeId] ?? const [];
      if (agents.every((agent) => agent.agentId != agentId)) return;
      return;
    }
    if (router != ChatRouter.local) return;
    final agent = _findAgent(value);
    if (agent == null) return;
    _selectAgent(agent);
  }

  bool _isThreadConversation({String? threadId}) {
    final resolvedThreadId = threadId ?? _activeSubSection;
    return resolvedThreadId != 'main';
  }

  Widget _buildRouterMenuOption({
    required BuildContext context,
    required String label,
    required bool selected,
    String? sublabel,
  }) {
    final hintStyle = Theme.of(context).textTheme.bodySmall;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: selected
              ? const Icon(Icons.check, size: 16)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: sublabel == null
              ? Text(label)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    Text(sublabel, style: hintStyle),
                  ],
                ),
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildSubSectionMenuItems(
    BuildContext context,
  ) {
    final items = <PopupMenuEntry<String>>[];

    if (_isThreadConversation()) {
      items.add(
        const PopupMenuItem<String>(
          value: 'main',
          child: Text('Back to Main Thread'),
        ),
      );
    }

    items.add(
      const PopupMenuItem<String>(
        value: _createSubSectionMenuValue,
        child: Text('New Thread'),
      ),
    );

    if (_isThreadConversation()) {
      items.add(const PopupMenuDivider());
      items.addAll(
        const [
          PopupMenuItem<String>(
            value: _renameSubSectionMenuValue,
            child: Text('Rename'),
          ),
          PopupMenuItem<String>(
            value: _archiveSubSectionMenuValue,
            child: Text('Archive'),
          ),
        ],
      );
    }

    if (_activeSubSections.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.addAll(
        _activeSubSections.map(
          (item) => PopupMenuItem<String>(
            value: item.id,
            child: Text(item.name),
          ),
        ),
      );
    }
    return items;
  }

  List<PopupMenuEntry<String>> _buildChannelMenuItems(BuildContext context) {
    ChatChannel? activeChannel;
    for (final channel in _channels) {
      if (channel.id == _activeChannelId) {
        activeChannel = channel;
        break;
      }
    }
    final canManageActiveChannel = activeChannel != null &&
        activeChannel.id == _activeChannelId &&
        !activeChannel.isDefault;

    return [
      PopupMenuItem<String>(
        value: _renameChannelMenuValue,
        enabled: canManageActiveChannel,
        child: const Text('Rename'),
      ),
      PopupMenuItem<String>(
        value: _archiveChannelMenuValue,
        enabled: canManageActiveChannel,
        child: const Text('Archive'),
      ),
      const PopupMenuDivider(),
      ..._sortedChannels.map(
        (channel) => PopupMenuItem<String>(
          value: channel.id,
          child: Text(channel.name),
        ),
      ),
    ];
  }

  BoxConstraints _channelMenuConstraints(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = math.min(
      _channelMenuMaxHeight,
      math.max(240.0, availableHeight - 96.0),
    );
    return BoxConstraints(
      minWidth: _channelMenuMinWidth,
      maxHeight: maxHeight,
    );
  }

  String? _sourceFromRespondRouter(String? router) {
    if (router == null ||
        router.isEmpty ||
        router == 'default' ||
        router == 'local') {
      return null;
    }
    if (router == 'openclaw' || router == 'plugin') {
      return 'backend.respond.openclaw';
    }
    return 'backend.respond.$router';
  }

  Future<void> _saveChannelRouter(ChatRouter router, {String? nodeId}) async {
    final channelId = _activeChannelId;
    final previous = _channelRouters[channelId];
    final previousNodeId = _channelNodeIds[channelId];
    final normalizedNodeId = _normalizeNodeId(nodeId);
    final effectiveRouter =
        router == ChatRouter.plugin && normalizedNodeId == null
            ? ChatRouter.local
            : router;
    setState(() {
      if (effectiveRouter == ChatRouter.local) {
        _channelRouters.remove(channelId);
        _channelNodeIds.remove(channelId);
      } else {
        _channelRouters[channelId] = effectiveRouter;
        if (normalizedNodeId == null || normalizedNodeId.isEmpty) {
          _channelNodeIds.remove(channelId);
        } else {
          _channelNodeIds[channelId] = normalizedNodeId;
        }
      }
    });
    _configureActiveScopeSync();

    try {
      await _chatHistoryApiService.saveScopeSetting(
        scopeType: ChatScopeType.channel,
        channelId: channelId,
        router: effectiveRouter,
        nodeId: effectiveRouter == ChatRouter.plugin ? normalizedNodeId : null,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _channelRouters.remove(channelId);
        } else {
          _channelRouters[channelId] = previous;
        }
        if (previousNodeId == null || previousNodeId.isEmpty) {
          _channelNodeIds.remove(channelId);
        } else {
          _channelNodeIds[channelId] = previousNodeId;
        }
      });
      _configureActiveScopeSync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save channel router: $error')),
      );
    }
  }

  Future<void> _saveThreadRouter(ChatRouter? router, {String? nodeId}) async {
    final channelId = _activeChannelId;
    final threadId = _activeSubSection;
    final key = _subSectionKey(channelId, threadId);
    final previous = _threadRouters[key];
    final previousNodeId = _threadNodeIds[key];
    final normalizedNodeId = _normalizeNodeId(nodeId);
    final effectiveRouter =
        router == ChatRouter.plugin && normalizedNodeId == null
            ? ChatRouter.local
            : router;
    setState(() {
      if (effectiveRouter == null) {
        _threadRouters.remove(key);
        _threadNodeIds.remove(key);
      } else {
        _threadRouters[key] = effectiveRouter;
        if (normalizedNodeId == null || normalizedNodeId.isEmpty) {
          _threadNodeIds.remove(key);
        } else {
          _threadNodeIds[key] = normalizedNodeId;
        }
      }
    });
    _configureActiveScopeSync();

    try {
      await _chatHistoryApiService.saveScopeSetting(
        scopeType: ChatScopeType.thread,
        channelId: channelId,
        threadId: threadId,
        router: effectiveRouter,
        nodeId: effectiveRouter == ChatRouter.plugin ? normalizedNodeId : null,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _threadRouters.remove(key);
        } else {
          _threadRouters[key] = previous;
        }
        if (previousNodeId == null || previousNodeId.isEmpty) {
          _threadNodeIds.remove(key);
        } else {
          _threadNodeIds[key] = previousNodeId;
        }
      });
      _configureActiveScopeSync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save thread router: $error')),
      );
    }
  }

  void _handleRouterMenuSelection(String value) {
    if (value.startsWith('channel:openclaw:')) {
      unawaited(
        _saveChannelRouter(
          ChatRouter.plugin,
          nodeId: value.substring('channel:openclaw:'.length),
        ),
      );
      return;
    }
    if (value.startsWith('thread:openclaw:')) {
      if (!_isThreadConversation()) return;
      unawaited(
        _saveThreadRouter(
          ChatRouter.plugin,
          nodeId: value.substring('thread:openclaw:'.length),
        ),
      );
      return;
    }
    switch (value) {
      case 'channel:default':
        unawaited(_saveChannelRouter(ChatRouter.local));
        return;
      case 'thread:inherit':
        if (!_isThreadConversation()) return;
        unawaited(_saveThreadRouter(null));
        return;
      case 'thread:default':
        if (!_isThreadConversation()) return;
        unawaited(_saveThreadRouter(ChatRouter.local));
        return;
    }
  }

  Future<void> _saveChannelInstructions(String? instructions) async {
    final channelId = _activeChannelId;
    final normalized = instructions?.trim();
    final previous = _channelInstructions[channelId];
    setState(() {
      if (normalized == null || normalized.isEmpty) {
        _channelInstructions.remove(channelId);
      } else {
        _channelInstructions[channelId] = normalized;
      }
    });

    final effectiveRouter = _channelRouters[channelId] ?? ChatRouter.local;

    try {
      await _chatHistoryApiService.saveScopeSetting(
        scopeType: ChatScopeType.channel,
        channelId: channelId,
        router: effectiveRouter,
        nodeId: effectiveRouter == ChatRouter.plugin
            ? _channelNodeIds[channelId]
            : null,
        instructions: normalized?.isEmpty ?? true ? null : normalized,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previous == null || previous.isEmpty) {
          _channelInstructions.remove(channelId);
        } else {
          _channelInstructions[channelId] = previous;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save channel instructions: $error')),
      );
    }
  }

  Future<void> _saveThreadInstructions(String? instructions) async {
    if (!_isThreadConversation()) return;

    final channelId = _activeChannelId;
    final threadId = _activeSubSection;
    final key = _subSectionKey(channelId, threadId);
    final normalized = instructions?.trim();
    final previous = _threadInstructions[key];
    setState(() {
      if (normalized == null || normalized.isEmpty) {
        _threadInstructions.remove(key);
      } else {
        _threadInstructions[key] = normalized;
      }
    });

    final effectiveRouter = _threadRouters[key] ?? ChatRouter.local;

    try {
      await _chatHistoryApiService.saveScopeSetting(
        scopeType: ChatScopeType.thread,
        channelId: channelId,
        threadId: threadId,
        router: effectiveRouter,
        nodeId:
            effectiveRouter == ChatRouter.plugin ? _threadNodeIds[key] : null,
        instructions: normalized?.isEmpty ?? true ? null : normalized,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previous == null || previous.isEmpty) {
          _threadInstructions.remove(key);
        } else {
          _threadInstructions[key] = previous;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save thread instructions: $error')),
      );
    }
  }

  Future<void> _openScopeConfigDialog() async {
    final isSubSection = _isThreadConversation();
    final channelId = _activeChannelId;
    final threadKey = _subSectionKey(channelId, _activeSubSection);

    final channelController = TextEditingController(
      text: _channelInstructions[channelId] ?? '',
    );
    final threadController = TextEditingController(
      text: isSubSection ? (_threadInstructions[threadKey] ?? '') : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ScopeConfigDialog(
        isSubSection: isSubSection,
        channelController: channelController,
        threadController: threadController,
        onSaveChannel: (value) async {
          Navigator.of(dialogContext).pop();
          await _saveChannelInstructions(value);
        },
        onSaveThread: (value) async {
          Navigator.of(dialogContext).pop();
          await _saveThreadInstructions(value);
        },
      ),
    );

    channelController.dispose();
    threadController.dispose();
  }

  void _updateSubSectionLastMessageAtFromMessages({
    String? channelId,
    String? subSection,
  }) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedSubSection = subSection ?? _activeSubSection;
    final latest = _messages.fold<DateTime?>(null, (current, message) {
      final candidate = message.createdAt ?? message.timestamp;
      if (current == null) return candidate;
      if (candidate.isAfter(current)) return candidate;
      return current;
    });
    if (latest == null) return;
    setState(() {
      _subSectionLastMessageAt[_subSectionKey(
        resolvedChannelId,
        resolvedSubSection,
      )] = latest;
      final currentChannelTime = _channelLastMessageAt[resolvedChannelId];
      if (currentChannelTime == null || latest.isAfter(currentChannelTime)) {
        _channelLastMessageAt[resolvedChannelId] = latest;
      }
    });
  }

  /// Looks up a sub-section name by id without triggering a sort, keeping
  /// build-path cost at O(n) instead of O(n log n).
  String? _subSectionNameById(String sectionId) {
    final items = _channelSubSections[_activeChannelId] ?? const [];
    for (final section in items) {
      if (section.id == sectionId) return section.name;
    }
    return null;
  }

  bool _hasPendingAssistantTasks() {
    return _messages.any(
      (message) =>
          message.role == 'assistant' &&
          (message.taskState == ChatTaskState.accepted ||
              message.taskState == ChatTaskState.dispatched),
    );
  }

  bool _hasPendingUserTasks() {
    final assistantTaskIds = _messages
        .where((m) => m.role == 'assistant' && m.taskId != null)
        .map((m) => m.taskId!)
        .toSet();
    return _messages.any(
      (message) =>
          message.role == 'user' &&
          message.taskId != null &&
          message.taskState == ChatTaskState.accepted &&
          !assistantTaskIds.contains(message.taskId),
    );
  }

  bool _shouldSyncActiveScope() {
    if (_effectiveRouterForScope() == ChatRouter.plugin) return true;
    if (_isSending || _isStreaming) return true;
    return _hasPendingAssistantTasks() || _hasPendingUserTasks();
  }

  void _disconnectSse() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
  }

  /// Starts (or restarts) the SSE connection for the active scope.
  /// Disconnects any existing connection first.  If [_shouldSyncActiveScope]
  /// returns false the connection is only torn down.
  void _connectSse() {
    _disconnectSse();
    if (!_shouldSyncActiveScope()) return;

    final capturedSessionId = _sessionIdForScope;
    final capturedChannelId = _activeChannelId;
    final capturedSubSection = _activeSubSection;

    _sseSubscription = _chatHistoryApiService
        .listenEvents(
      sessionId: capturedSessionId,
      afterSeq: _lastSyncedSeq,
    )
        .listen(
      (snapshot) {
        if (!mounted || _sessionIdForScope != capturedSessionId) return;
        _applySseSnapshot(
          snapshot,
          channelId: capturedChannelId,
          subSection: capturedSubSection,
        );
      },
      onError: (Object error) {
        debugPrint('SSE chat events error: $error');
        if (mounted && _sessionIdForScope == capturedSessionId) {
          Future.delayed(_sseReconnectDelay, _connectSse);
        }
      },
      onDone: () {
        if (mounted &&
            _sessionIdForScope == capturedSessionId &&
            _shouldSyncActiveScope()) {
          Future.delayed(_sseReconnectDelay, _connectSse);
        }
      },
    );
  }

  void _configureActiveScopeSync() {
    if (!_shouldSyncActiveScope()) {
      _disconnectSse();
      return;
    }
    _connectSse();
  }

  List<ChatMessage> _mergeSyncedMessages(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    final merged = [...current];
    final byId = <String, int>{};
    for (var i = 0; i < merged.length; i++) {
      final messageId = merged[i].messageId;
      if (messageId != null && messageId.isNotEmpty) {
        byId[messageId] = i;
      }
    }

    for (final message in incoming) {
      final normalized = message.copyWith(
        isStreaming: false,
        taskState: normalizedServerTaskState(message),
      );
      final messageId = normalized.messageId;
      if (messageId != null && byId.containsKey(messageId)) {
        final index = byId[messageId]!;
        merged[index] = mergeServerMessage(merged[index], normalized);
        continue;
      }
      merged.add(normalized);
      if (messageId != null && messageId.isNotEmpty) {
        byId[messageId] = merged.length - 1;
      }
    }

    merged.sort(compareChatMessagesByCreatedTime);
    return merged;
  }

  void _applySseSnapshot(
    ChatHistorySnapshot snapshot, {
    required String channelId,
    required String subSection,
  }) {
    if (snapshot.messages.isEmpty && snapshot.lastSeqId <= _lastSyncedSeq) {
      return;
    }
    final merged = _mergeSyncedMessages(_messages, snapshot.messages);
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
      if (snapshot.lastSeqId > _lastSyncedSeq) {
        _lastSyncedSeq = snapshot.lastSeqId;
      }
    });
    _updateSubSectionLastMessageAtFromMessages(
      channelId: channelId,
      subSection: subSection,
    );
    _consumeChatInvalidations(snapshot);
  }

  void _consumeChatInvalidations(ChatHistorySnapshot snapshot) {
    var refreshScopes = false;
    var refreshChannels = false;
    var refreshScopeSettings = false;
    var refreshResources = false;

    for (final message in snapshot.messages) {
      final taskId = message.taskId;
      for (final invalidation in message.invalidations) {
        if (taskId != null && taskId.isNotEmpty) {
          final dedupeKey = '$taskId:${invalidation.kind.value}';
          if (!_topologyRefreshedTaskIds.add(dedupeKey)) continue;
        }
        switch (invalidation.kind) {
          case ChatInvalidationKind.chatScopes:
            refreshScopes = true;
          case ChatInvalidationKind.chatChannelNames:
            refreshChannels = true;
          case ChatInvalidationKind.chatScopeSettings:
            refreshScopeSettings = true;
          case ChatInvalidationKind.resourcesTodoLists:
          case ChatInvalidationKind.resourcesTodos:
          case ChatInvalidationKind.resourcesTables:
          case ChatInvalidationKind.resourcesTableColumns:
          case ChatInvalidationKind.resourcesTableRows:
          case ChatInvalidationKind.resourcesNotes:
            refreshResources = true;
            break;
        }
      }
    }

    if (refreshScopes || refreshChannels || refreshScopeSettings) {
      unawaited(
        _refreshScopeTopologyParts(
          refreshScopes: refreshScopes,
          refreshChannels: refreshChannels,
          refreshScopeSettings: refreshScopeSettings,
        ),
      );
    }
    if (refreshResources) {
      unawaited(_refreshResources());
    }
  }

  List<ChatPersistedScope> _currentPersistedScopes() => [
        for (final channel in _channels)
          ChatPersistedScope(
            channelId: channel.id,
            threadId: 'main',
            sessionId: ChatSessionScope(channelId: channel.id, threadId: 'main')
                .sessionId,
            lastActivityAt: _channelLastMessageAt[channel.id],
          ),
        for (final sections in _channelSubSections.values)
          for (final section in sections)
            ChatPersistedScope(
              channelId: section.parentChannelId,
              threadId: section.id,
              sessionId: ChatSessionScope(
                channelId: section.parentChannelId,
                threadId: section.id,
              ).sessionId,
              lastActivityAt: _subSectionLastMessageAt[
                  _subSectionKey(section.parentChannelId, section.id)],
            ),
      ];

  List<ChatChannelSetting> _currentChannelSettings() => [
        for (final channel in _channels)
          ChatChannelSetting(
            channelId: channel.id,
            displayName: channel.name,
            scopeType: ChatScopeType.channel,
          ),
        for (final sections in _channelSubSections.values)
          for (final section in sections)
            ChatChannelSetting(
              channelId: section.parentChannelId,
              threadId: section.id,
              displayName: section.name,
              scopeType: ChatScopeType.thread,
            ),
      ];

  Future<void> _refreshScopeTopologyParts({
    required bool refreshScopes,
    required bool refreshChannels,
    required bool refreshScopeSettings,
  }) async {
    if (_refreshingScopeTopology) return;
    _refreshingScopeTopology = true;
    try {
      final results = await Future.wait<Object>([
        if (refreshScopes) _chatHistoryApiService.loadScopes(),
        if (refreshChannels) _chatHistoryApiService.loadChannels(),
        if (refreshScopeSettings) _chatHistoryApiService.loadScopeSettings(),
      ]);
      if (!mounted) return;
      var index = 0;
      final scopes = refreshScopes
          ? results[index++] as List<ChatPersistedScope>
          : _currentPersistedScopes();
      final channels = refreshChannels
          ? results[index++] as List<ChatChannelSetting>
          : _currentChannelSettings();
      final settings = refreshScopeSettings
          ? results[index++] as List<ChatScopeSetting>
          : const <ChatScopeSetting>[];
      final restoredChannels = _hydrateChannelsFromRegistry(channels);
      final restoredChannelLastMessageAt = _hydrateChannelLastMessageAt(scopes);
      final restoredSubSections = _hydrateSubSectionsFromRegistry(channels);
      final restoredLastSubSectionByChannel =
          _hydrateLastActiveSubSectionByChannel(scopes, restoredSubSections);

      setState(() {
        if (refreshScopes || refreshChannels) {
          _channels
            ..clear()
            ..addAll(restoredChannels);
          _channelLastMessageAt
            ..clear()
            ..addAll(restoredChannelLastMessageAt);
          _channelSubSections
            ..clear()
            ..addAll(restoredSubSections);
          _lastActiveSubSectionByChannel
            ..clear()
            ..addAll(restoredLastSubSectionByChannel);
        }
        if (refreshScopeSettings) {
          _channelRouters
            ..clear()
            ..addAll(_hydrateChannelRouters(settings));
          _threadRouters
            ..clear()
            ..addAll(_hydrateThreadRouters(settings));
          _channelNodeIds
            ..clear()
            ..addAll(_hydrateChannelNodeIds(settings));
          _threadNodeIds
            ..clear()
            ..addAll(_hydrateThreadNodeIds(settings));
          _channelInstructions
            ..clear()
            ..addAll(_hydrateChannelInstructions(settings));
          _threadInstructions
            ..clear()
            ..addAll(_hydrateThreadInstructions(settings));
        }
      });
    } catch (error) {
      debugPrint('refreshScopeTopology failed: $error');
    } finally {
      _refreshingScopeTopology = false;
    }
  }

  void _createSubSection() {
    final name = _timestampName(prefix: 'sub');
    final id = _newId('sub');
    final section = ChatSubSection(
      id: id,
      parentChannelId: _activeChannelId,
      name: name,
      createdAt: DateTime.now(),
    );
    setState(() {
      final items = _channelSubSections.putIfAbsent(
        _activeChannelId,
        () => <ChatSubSection>[],
      );
      items.add(section);
      _activeSubSection = id;
      _lastActiveSubSectionByChannel[_activeChannelId] = id;
      _messages.clear();
      _archivedMessageIds.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    _configureActiveScopeSync();
    unawaited(
      _chatHistoryApiService
          .saveChannel(
        channelId: _activeChannelId,
        threadId: section.id,
        displayName: section.name,
      )
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to save subsection "${section.id}": $error');
      }),
    );
  }

  void _renameActiveSubSection() {
    if (!_isThreadConversation()) return;
    final channelId = _activeChannelId;
    final sectionId = _activeSubSection;
    ChatSubSection? section;
    for (final item in _channelSubSections[channelId] ?? const []) {
      if (item.id == sectionId) {
        section = item;
        break;
      }
    }
    final existingSection = section;
    if (existingSection == null) return;
    final existingNames = (_channelSubSections[channelId] ?? const [])
        .where((item) => item.id != sectionId)
        .map((item) => item.name.trim().toLowerCase())
        .toSet();
    _promptChannelName(
      title: 'Rename Thread',
      confirmLabel: 'Save',
      initialValue: existingSection.name,
      fieldLabel: 'Thread name',
      hintText: 'Enter a thread name',
      emptyError: 'Thread name is required',
      duplicateError: 'Thread name already exists',
      existingNames: existingNames,
      onConfirmed: (name) {
        setState(() {
          final sections = _channelSubSections[channelId];
          if (sections == null) return;
          final index = sections.indexWhere((item) => item.id == sectionId);
          if (index < 0) return;
          sections[index] = ChatSubSection(
            id: existingSection.id,
            parentChannelId: existingSection.parentChannelId,
            name: name,
            createdAt: existingSection.createdAt,
          );
        });
        unawaited(
          _chatHistoryApiService
              .saveChannel(
            channelId: channelId,
            threadId: sectionId,
            displayName: name,
          )
              .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Failed to save subsection name "$sectionId": $error');
          }),
        );
      },
    );
  }

  void _archiveActiveSubSection() {
    if (!_isThreadConversation()) return;
    final channelId = _activeChannelId;
    final sectionId = _activeSubSection;
    final sectionName = _subSectionNameById(sectionId) ?? sectionId;
    final sectionKey = _subSectionKey(channelId, sectionId);
    setState(() {
      _channelSubSections[channelId]?.removeWhere(
        (item) => item.id == sectionId,
      );
      _subSectionLastMessageAt.remove(sectionKey);
      _threadRouters.remove(sectionKey);
      _threadNodeIds.remove(sectionKey);
      _threadInstructions.remove(sectionKey);
      _lastActiveSubSectionByChannel[channelId] = 'main';
      _activeSubSection = 'main';
      _messages.clear();
      _archivedMessageIds.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    _configureActiveScopeSync();
    unawaited(_loadMessagesForActiveScope());
    unawaited(
      _chatHistoryApiService
          .archiveChannel(
        channelId: channelId,
        threadId: sectionId,
        displayName: sectionName,
      )
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to archive subsection "$sectionId": $error');
      }),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archived thread: $sectionName')),
    );
  }

  void _switchToSubSection(String subSectionId) {
    setState(() {
      _activeSubSection = subSectionId;
      _lastActiveSubSectionByChannel[_activeChannelId] = subSectionId;
      _messages.clear();
      _archivedMessageIds.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    unawaited(_loadMessagesForActiveScope());
  }

  Future<AgentSession> _sessionForAgent(AgentDefinition? agent) async {
    final key = agent?.name ?? '_default';
    final existing = _sessions[key];
    if (existing != null) return existing;
    final session = _client.createSession(_settingsForAgent(agent));
    _sessions[key] = session;
    return session;
  }

  void _updateMessageContent(
    int index,
    String content, {
    bool isStreaming = false,
  }) {
    if (!mounted || index < 0 || index >= _messages.length) return;
    setState(() {
      _messages[index] = _messages[index].copyWith(
        content: content,
        isStreaming: isStreaming,
      );
    });
  }

  int _appendMessage(ChatMessage message) {
    final normalized = message.copyWith(
      messageId: message.messageId ?? _newId('msg'),
      channelId: message.channelId ?? _activeScope.channelId,
      sessionId: message.sessionId ?? _activeScope.sessionId,
      threadId: message.threadId ??
          (_activeScope.threadId == 'main' ? null : _activeScope.threadId),
    );
    final messageTime = normalized.createdAt ?? normalized.timestamp;
    setState(() {
      _messages.add(normalized);
      _subSectionLastMessageAt[_subSectionKey(
        _activeScope.channelId,
        _activeScope.threadId,
      )] = messageTime;
      final currentChannelTime = _channelLastMessageAt[_activeScope.channelId];
      if (currentChannelTime == null ||
          messageTime.isAfter(currentChannelTime)) {
        _channelLastMessageAt[_activeScope.channelId] = messageTime;
      }
    });
    return _messages.length - 1;
  }

  int _indexOfMessageId(String? messageId) {
    if (messageId == null || messageId.isEmpty) return -1;
    return _messages.indexWhere((message) => message.messageId == messageId);
  }

  bool _updateMessageById(
    String? messageId,
    ChatMessage Function(ChatMessage current) updater, {
    void Function()? onStateUpdate,
  }) {
    if (!mounted) return false;
    final targetIndex = _indexOfMessageId(messageId);
    if (targetIndex < 0) return false;
    setState(() {
      _messages[targetIndex] = updater(_messages[targetIndex]);
      onStateUpdate?.call();
    });
    return true;
  }

  String _mimeTypeForPickedFile(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'png':
      default:
        return 'image/png';
    }
  }

  Future<void> _attachImageToDraft() async {
    if (_isUploadingAttachment || _isSending) return;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final file =
          result == null || result.files.isEmpty ? null : result.files.first;
      final bytes = file?.bytes;
      if (file == null || bytes == null || bytes.isEmpty) return;
      final mimeType = _mimeTypeForPickedFile(file);
      final dataBase64 = base64Encode(bytes);
      final generation = ++_imageUploadGeneration;
      setState(() {
        _isUploadingAttachment = true;
        _draftUpload = ComposerDraftUpload(
          filename: file.name,
          mimeType: mimeType,
          dataBase64: dataBase64,
          isUploading: true,
        );
      });
      await _uploadDraftImage(
        filename: file.name,
        mimeType: mimeType,
        dataBase64: dataBase64,
        generation: generation,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingAttachment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $error')),
      );
    }
  }

  Future<void> _uploadDraftImage({
    required String filename,
    required String mimeType,
    required String dataBase64,
    required int generation,
  }) async {
    try {
      final attachment = await _chatHistoryApiService.uploadImage(
        scope: _activeScope,
        filename: filename,
        mimeType: mimeType,
        dataBase64: dataBase64,
      );
      if (!mounted || generation != _imageUploadGeneration) return;
      setState(() {
        _pendingMediaAttachments.add(attachment);
        _draftUpload = null;
        _isUploadingAttachment = false;
      });
    } catch (error) {
      if (!mounted || generation != _imageUploadGeneration) return;
      setState(() {
        _draftUpload = ComposerDraftUpload(
          filename: filename,
          mimeType: mimeType,
          dataBase64: dataBase64,
          isUploading: false,
          errorText: error.toString(),
        );
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $error')),
      );
    }
  }

  void _retryDraftImageUpload() {
    final draft = _draftUpload;
    if (draft == null || draft.isUploading || _isSending) return;
    final generation = ++_imageUploadGeneration;
    setState(() {
      _isUploadingAttachment = true;
      _draftUpload = ComposerDraftUpload(
        filename: draft.filename,
        mimeType: draft.mimeType,
        dataBase64: draft.dataBase64,
        isUploading: true,
      );
    });
    unawaited(
      _uploadDraftImage(
        filename: draft.filename,
        mimeType: draft.mimeType,
        dataBase64: draft.dataBase64,
        generation: generation,
      ),
    );
  }

  void _cancelDraftImageUpload() {
    _imageUploadGeneration++;
    setState(() {
      _draftUpload = null;
      _isUploadingAttachment = false;
    });
  }

  void _removePendingAttachment(String mediaId) {
    setState(() {
      _pendingMediaAttachments.removeWhere((item) => item.id == mediaId);
    });
  }

  void _sendMessage(String text) {
    final attachments =
        List<ChatMediaAttachment>.unmodifiable(_pendingMediaAttachments);
    if ((text.trim().isEmpty && attachments.isEmpty) || _isSending) return;

    final agent = _activeAgent;
    final activeParticipants = _participantManager.participants.active;
    final positiveCandidates =
        activeParticipants.where((item) => item.probability > 1e-9).toList();
    final arbitrationMode = positiveCandidates.length > 1;
    final arbitration = _arbitrationEngine.resolve(
      candidates: positiveCandidates
          .map(
            (item) => ArbitrationCandidate(
              botId: item.agentId,
              baseWeight: item.probability,
            ),
          )
          .toList(),
      requestedBotId: agent?.name,
    );
    final dispatch = arbitration.selected;
    final resolvedBotId = dispatch.bot.id;
    final resolvedSkillId = dispatch.skillId;
    final taskId = _newId('task');
    final idempotencyKey = _newId('idem');
    final traceId = _newId('trace');
    final userMessageId = _newId('msg');
    final assistantMessageId = _newId('msg');
    final envelope = ChatTaskEnvelope(
      taskId: taskId,
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now(),
      channelId: _activeScope.channelId,
      sessionId: _activeScope.sessionId,
      threadId: _activeScope.threadId == 'main' ? null : _activeScope.threadId,
    );
    final ack = _taskProtocol.acknowledge(envelope);
    _latestCheckpointCursor = ack.checkpointCursor;

    final scoreSummary = arbitration.candidateScores
        .map((item) => '${item.botId}:${item.score.toStringAsFixed(2)}')
        .join(', ');
    final userMessage = ChatMessage(
      messageId: userMessageId,
      role: 'user',
      content: text,
      mediaAttachments: attachments,
      taskId: taskId,
      idempotencyKey: idempotencyKey,
      createdAt: envelope.createdAt,
      channelId: envelope.channelId,
      sessionId: envelope.sessionId,
      threadId: envelope.threadId,
      resolvedBotId: resolvedBotId,
      resolvedSkillId: resolvedSkillId,
      arbitrationMode: arbitrationMode,
      tieDetected: arbitration.tieDetected,
      tieBotIds: arbitration.tieBotIds,
      selectedScore: arbitration.selectedScore,
      candidateScoreSummary: scoreSummary.isEmpty ? null : scoreSummary,
      decisionReason: arbitration.reason,
      traceId: arbitrationMode ? traceId : null,
    );
    _appendMessage(userMessage);

    setState(() {
      _isSending = true;
      _isStreaming = false;
      _pendingMediaAttachments.clear();
      _draftUpload = null;
    });

    final runtimeSettings = _settingsForAgent(agent);

    final generation = ++_respondGeneration;
    _chatHistoryApiService
        .respond(
      taskId: taskId,
      idempotencyKey: idempotencyKey,
      scope: _activeScope,
      userMessageId: userMessageId,
      assistantMessageId: assistantMessageId,
      userMessage: text,
      mediaAttachmentIds: attachments.map((item) => item.id).toList(),
      resolvedBotId: resolvedBotId,
      resolvedSkillId: resolvedSkillId,
      provider: runtimeSettings.provider,
      model: runtimeSettings.model,
      configId: runtimeSettings.configId,
      nodeId: _effectiveNodeIdForScope(),
      systemPrompt: runtimeSettings.systemPrompt,
      createdAt: envelope.createdAt,
    )
        .then((result) async {
      if (!mounted) return;
      // Ignore stale completions if stop was pressed after this request started.
      if (generation != _respondGeneration) return;
      final updated = _updateMessageById(
        userMessageId,
        (current) => current.copyWith(
          // Stamp the server-assigned write sequence on the user message so
          // that the sort comparator can order it correctly against the
          // incoming assistant reply (which will have a higher writeSeq).
          writeSeq: result.lastSeqId > 0 ? result.lastSeqId : current.writeSeq,
          taskState: result.taskState ?? ChatTaskState.accepted,
          source: _sourceFromRespondRouter(result.router) ?? current.source,
          acknowledgedAt: ack.acceptedAt,
          checkpointCursor: ack.checkpointCursor,
        ),
        onStateUpdate: () {
          if (result.lastSeqId > _lastSyncedSeq) {
            _lastSyncedSeq = result.lastSeqId;
          }
          _isSending = false;
          _isStreaming = false;
        },
      );
      if (!updated) {
        setState(() {
          _isSending = false;
          _isStreaming = false;
        });
        return;
      }
      _configureActiveScopeSync();
      // Backend now persists assistant responses asynchronously; skip
      // client-side assistant placeholder/upsert and rely on SSE/sync.
      if (result.isAsync) return;
      if (mounted) {
        await _handleProactiveResponses(text);
        if (mounted) {
          setState(() {
            _isSending = false;
            _isStreaming = false;
          });
        }
      }
    }).catchError((error) {
      if (!mounted) return;
      if (generation != _respondGeneration) return;
      final updated = _updateMessageById(
        userMessageId,
        (current) {
          return current.copyWith(
            taskState: ChatTaskState.failed,
          );
        },
        onStateUpdate: () {
          _isSending = false;
          _isStreaming = false;
        },
      );
      if (!updated) {
        setState(() {
          _isSending = false;
          _isStreaming = false;
        });
        return;
      }
    });
  }

  void _stopStreaming() {
    _currentSubscription?.cancel();
    _currentSubscription = null;
    // Invalidate any in-flight /chat/respond Future so its completion handler
    // won't overwrite the cancelled state we set below.
    _respondGeneration++;
    if (mounted) {
      setState(() {
        _isSending = false;
        _isStreaming = false;
        // Mark any streaming messages as complete.
        for (var i = _messages.length - 1; i >= 0; i--) {
          if (_messages[i].isStreaming) {
            _messages[i] = _messages[i].copyWith(
              isStreaming: false,
              taskState: ChatTaskState.cancelled,
            );
            break;
          }
        }
      });
    }
  }

  AgentDefinition? _findAgent(String agentId) {
    for (final agent in _agents) {
      if (agent.name == agentId) return agent;
    }
    return null;
  }

  Future<void> _handleProactiveResponses(String userMessage) async {
    final speakers = _participantManager.decideProactiveSpeakers();
    final futures = <Future<void>>[];
    for (final agentId in speakers) {
      final participant = _participantManager.participants.findById(agentId);
      final agent = _findAgent(agentId);
      if (participant == null || agent == null) continue;
      futures.add(_runAgentResponse(agent, participant.agentName, userMessage));
    }
    await Future.wait(futures);
  }

  Future<void> _runAgentResponse(
    AgentDefinition agent,
    String agentName,
    String userMessage,
  ) async {
    final index = _appendMessage(
      ChatMessage(
        role: 'assistant',
        content: '',
        agentId: agent.name,
        agentName: agentName,
        isStreaming: true,
      ),
    );
    final session = await _sessionForAgent(agent);
    try {
      await for (final event in session.sendMessage(userMessage)) {
        if (event is TextDeltaEvent) {
          final current = _messages[index];
          _updateMessageContent(
            index,
            current.content + event.delta,
            isStreaming: true,
          );
        } else if (event is MessageCompleteEvent) {
          _updateMessageContent(index, event.fullText, isStreaming: false);
        } else if (event is AgentErrorEvent) {
          _updateMessageContent(
            index,
            'Error: ${event.message}',
            isStreaming: false,
          );
        }
      }
    } catch (e) {
      _updateMessageContent(index, 'Error: $e', isStreaming: false);
    }
  }

  Future<void> _openSettingsScreen() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    if (!mounted) return;
    await _refreshPlatformNodes();
  }

  Future<void> _refreshPlatformNodes() async {
    try {
      final nodes = await _llmConfigService.fetchPlatformNodes();
      if (!mounted) return;
      setState(() {
        _platformNodes = nodes;
      });
    } catch (e) {
      debugPrint('refreshPlatformNodes failed: $e');
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _showDebugInfoDialog() async {
    final activeParticipants = _participantManager.participants.active;
    final mode = activeParticipants.length > 1 ? 'Arbitration' : 'Direct';
    final activeSubSectionName = _subSectionNameById(_activeSubSection);
    final subSectionLabel = _activeSubSection == 'main'
        ? 'Thread'
        : (activeSubSectionName ?? _activeSubSection);
    final rows = <({String label, String value})>[
      (label: 'Channel', value: _activeChannelId),
      (label: 'Thread', value: subSectionLabel),
      (label: 'Session', value: _sessionIdForScope),
      (label: 'Mode', value: mode),
      if (_latestCheckpointCursor != null)
        (label: 'Cursor', value: _latestCheckpointCursor!),
      (label: 'Seq', value: '$_lastSyncedSeq'),
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: BricksSpacing.xs),
                  child: SelectableText('${row.label}: ${row.value}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _highlightResourceTitle(TextHighlight highlight) {
    final normalized = highlight.selectedText.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    return normalized.isEmpty ? 'Untitled highlight' : normalized;
  }

  Widget _buildNavigationContent({
    required ThemeData theme,
    required Color drawerBackgroundColor,
    VoidCallback? onRequestClose,
    bool closeOnChannelSelected = true,
  }) {
    return SafeArea(
      child: Theme(
        data: theme.copyWith(scaffoldBackgroundColor: drawerBackgroundColor),
        child: ChatNavigationPage(
          channels: _sortedChannels
              .map(
                (item) => ChatChannelItem(
                  id: item.id,
                  name: item.name,
                  isDefault: item.isDefault,
                ),
              )
              .toList(),
          nodes: _platformNodes.map((node) {
            final nodeAgents = _openClawAgentsByNodeId[node.nodeId] ?? [];
            return ChatNodeItem(
              id: node.nodeId,
              name: node.displayName,
              agents: nodeAgents
                  .map(
                    (a) => ChatAgentItem(
                      name: a.displayName,
                      prompt: '',
                      description: a.description,
                    ),
                  )
                  .toList(growable: false),
            );
          }).toList(growable: false),
          resources: [
            ..._todoLists.map(
              (t) => ChatResourceItem(
                id: t.id,
                type: ChatResourceType.todoList,
                title: t.title,
                updatedAt: t.updatedAt,
                notes: t.notes,
              ),
            ),
            ..._assetTables.map(
              (t) => ChatResourceItem(
                id: t.resourceId,
                type: ChatResourceType.assetTable,
                title: t.title,
                updatedAt: t.updatedAt,
              ),
            ),
            ..._notes.map(
              (n) => ChatResourceItem(
                id: n.id,
                type: ChatResourceType.note,
                title: n.title,
                updatedAt: n.updatedAt,
                notes: n.preview,
              ),
            ),
            ..._textHighlights.map(
              (h) => ChatResourceItem(
                id: h.id,
                type: ChatResourceType.textHighlight,
                title: _highlightResourceTitle(h),
                updatedAt: h.updatedAt,
                notes: 'Highlighted text',
              ),
            ),
          ],
          selectedChannelId: _activeChannelId,
          onChannelSelected: _switchChannel,
          onChannelRename: _renameChannel,
          onChannelArchive: _archiveChannel,
          onRequestClose: onRequestClose,
          closeOnChannelSelected: closeOnChannelSelected,
          todoApiService: _todoApiService,
          noteApiService: _noteApiService,
          onActionSelected: (action) {
            switch (action) {
              case ChatNavigationAction.appSettings:
                _openSettingsScreen();
                break;
              case ChatNavigationAction.sessions:
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sessions coming soon')),
                );
                break;
              case ChatNavigationAction.createChannel:
                _createChannel();
                break;
              case ChatNavigationAction.manageAgents:
                _openAgentsScreen();
                break;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAgents || _loadingLlmConfigs) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isCompactDarkChat = theme.brightness == Brightness.dark &&
        MediaQuery.sizeOf(context).width < 600;
    final isCompactChat = MediaQuery.sizeOf(context).width < 600;
    final chatBackgroundColor = isCompactDarkChat
        ? AppColors.backgroundChrome
        : theme.scaffoldBackgroundColor;
    final composerBackgroundColor =
        isCompactDarkChat ? AppColors.backgroundBase : null;
    final drawerBackgroundColor = theme.brightness == Brightness.dark
        ? AppColors.backgroundChrome
        : theme.colorScheme.surface;
    final drawerWidth =
        isCompactChat ? MediaQuery.sizeOf(context).width : 260.0;

    String activeChannelName = 'Channel';
    for (final item in _channels) {
      if (item.id == _activeChannelId) {
        activeChannelName = item.name;
        break;
      }
    }
    final isDesktop = !isCompactChat;

    // Build the shared AppBar widget. On mobile it is passed to
    // Scaffold.appBar so that status-bar insets are handled correctly. On
    // desktop it is rendered inline so the sidebar can span the full height.
    final appBar = AppBar(
      backgroundColor: chatBackgroundColor,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          tooltip: isDesktop
              ? (_isDesktopNavigationOpen
                  ? 'Close navigation'
                  : 'Open navigation')
              : 'Open navigation',
          onPressed: () {
            if (isDesktop) {
              setState(() {
                _isDesktopNavigationOpen = !_isDesktopNavigationOpen;
              });
              return;
            }
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
            tooltip: 'Switch channel',
            constraints: _channelMenuConstraints(context),
            onSelected: (value) {
              switch (value) {
                case _renameChannelMenuValue:
                  _renameChannel(_activeChannelId);
                  return;
                case _archiveChannelMenuValue:
                  _archiveChannel(_activeChannelId);
                  return;
                default:
                  _switchChannel(value);
                  return;
              }
            },
            itemBuilder: _buildChannelMenuItems,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    activeChannelName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
            tooltip: 'Thread menu',
            onSelected: (value) {
              switch (value) {
                case _createSubSectionMenuValue:
                  _createSubSection();
                  unawaited(_loadMessagesForActiveScope());
                  break;
                case _renameSubSectionMenuValue:
                  _renameActiveSubSection();
                  break;
                case _archiveSubSectionMenuValue:
                  _archiveActiveSubSection();
                  break;
                default:
                  _switchToSubSection(value);
              }
            },
            itemBuilder: _buildSubSectionMenuItems,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _activeSubSection == 'main'
                        ? 'Thread'
                        : (_subSectionNameById(_activeSubSection) ??
                            _activeSubSection),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_outlined),
          tooltip: 'Conversation config',
          onPressed: _openScopeConfigDialog,
        ),
      ],
    );

    // Message list + composer bar (shared between mobile and desktop).
    final chatContent = Column(
      children: [
        Expanded(
          child: MessageList(
            messages: _archivedMessageIds.isEmpty
                ? _messages
                : _messages
                    .where((m) =>
                        m.messageId == null ||
                        !_archivedMessageIds.contains(m.messageId))
                    .toList(),
            highlights: _highlights,
            onHighlight: _handleHighlight,
            onDeleteHighlight: _handleDeleteHighlight,
            onArchiveRound: _handleArchiveRound,
            onArchiveReply: _handleArchiveReply,
            onFork: _handleFork,
            onBranch: _handleBranch,
            onResend: _handleResend,
          ),
        ),
        Builder(
          builder: (context) {
            final effectiveRouter = _effectiveRouterForScope();
            final showComposerConfigMenu =
                effectiveRouter == ChatRouter.local ||
                    effectiveRouter == ChatRouter.plugin;
            final slashCommands = effectiveRouter == ChatRouter.plugin
                ? _openClawSlashCommands
                : const <String>[];
            final atActions = _composerAtActions(effectiveRouter);
            return ComposerBar(
              activeAgent: _activeAgent,
              agents: _agents,
              backgroundColor: composerBackgroundColor,
              leadingActions: [
                PopupMenuButton<String>(
                  popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
                  tooltip: 'Router settings',
                  onSelected: _handleRouterMenuSelection,
                  itemBuilder: (context) {
                    final isThreadConversation = _isThreadConversation();
                    final channelRouter = _effectiveChannelRouter(
                      channelId: _activeChannelId,
                    );
                    final channelNodeId = channelRouter == ChatRouter.plugin
                        ? _normalizeNodeId(
                            _channelNodeIds[_activeChannelId],
                          )
                        : null;
                    final channelRouterLabel = _routerLabel(channelRouter);
                    final explicitThreadRouter =
                        _effectiveExplicitThreadRouter();
                    final explicitThreadNodeId =
                        explicitThreadRouter == ChatRouter.plugin
                            ? _normalizeNodeId(_explicitThreadNodeId())
                            : null;
                    return [
                      if (!isThreadConversation) ...[
                        PopupMenuItem<String>(
                          enabled: false,
                          child: const Text('Channel router'),
                        ),
                        PopupMenuItem<String>(
                          value: 'channel:default',
                          child: _buildRouterMenuOption(
                            context: context,
                            label: 'Bricks Default',
                            selected: channelRouter == ChatRouter.local,
                          ),
                        ),
                        ..._platformNodes.map(
                          (node) => PopupMenuItem<String>(
                            value: 'channel:openclaw:${node.nodeId}',
                            child: _buildRouterMenuOption(
                              context: context,
                              label: _platformNodeLabel(node),
                              sublabel: 'OpenClaw',
                              selected: channelRouter == ChatRouter.plugin &&
                                  channelNodeId ==
                                      _normalizeNodeId(node.nodeId),
                            ),
                          ),
                        ),
                      ],
                      if (isThreadConversation) ...[
                        PopupMenuItem<String>(
                          enabled: false,
                          child: const Text('Thread router'),
                        ),
                        PopupMenuItem<String>(
                          value: 'thread:inherit',
                          child: _buildRouterMenuOption(
                            context: context,
                            label: 'Follow channel',
                            sublabel: channelRouter == ChatRouter.plugin
                                ? '${_nodeLabel(channelNodeId)} · $channelRouterLabel'
                                : channelRouterLabel,
                            selected: explicitThreadRouter == null,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'thread:default',
                          child: _buildRouterMenuOption(
                            context: context,
                            label: 'Bricks Default',
                            selected: explicitThreadRouter == ChatRouter.local,
                          ),
                        ),
                        ..._platformNodes.map(
                          (node) => PopupMenuItem<String>(
                            value: 'thread:openclaw:${node.nodeId}',
                            child: _buildRouterMenuOption(
                              context: context,
                              label: _platformNodeLabel(node),
                              sublabel: 'OpenClaw',
                              selected:
                                  explicitThreadRouter == ChatRouter.plugin &&
                                      explicitThreadNodeId ==
                                          _normalizeNodeId(node.nodeId),
                            ),
                          ),
                        ),
                      ],
                    ];
                  },
                  icon: SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: _effectiveRouterForScope() == ChatRouter.plugin
                          ? const Icon(Icons.hub_outlined, size: 20)
                          : const Icon(Icons.alt_route, size: 20),
                    ),
                  ),
                ),
              ],
              showComposerConfigMenu: showComposerConfigMenu,
              activeModelLabel: _currentComposerModelLabel(),
              slashCommands: slashCommands,
              atActions: atActions,
              onAtActionSelected: (value) =>
                  _handleComposerAtSelection(effectiveRouter, value),
              onOpenModelSelection: _openRuntimeModelConfigDialog,
              onShowInfo: _showDebugInfoDialog,
              onSend: _isSending ? null : _sendMessage,
              onAttachImage:
                  _isUploadingAttachment ? null : _attachImageToDraft,
              onCancelDraftUpload: _cancelDraftImageUpload,
              onRetryDraftUpload: _retryDraftImageUpload,
              onRemoveAttachment: _removePendingAttachment,
              attachments: _pendingMediaAttachments,
              draftUpload: _draftUpload,
              onStop: _stopStreaming,
              isStreaming: _isStreaming,
            );
          },
        ),
      ],
    );

    if (isDesktop) {
      // On desktop the sidebar spans the full screen height so the AppBar is
      // rendered inline (not as Scaffold.appBar) and is pushed to the right of
      // the sidebar when the sidebar is open.
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: chatBackgroundColor,
          body: Row(
            children: [
              if (_isDesktopNavigationOpen) ...[
                SizedBox(
                  width: _desktopNavigationWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: drawerBackgroundColor),
                    child: _buildNavigationContent(
                      theme: theme,
                      drawerBackgroundColor: drawerBackgroundColor,
                      onRequestClose: () => setState(
                        () => _isDesktopNavigationOpen = false,
                      ),
                      closeOnChannelSelected: false,
                    ),
                  ),
                ),
                // Resizable drag handle
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _desktopNavigationWidth =
                            (_desktopNavigationWidth + details.delta.dx).clamp(
                          _kMinSidebarWidth,
                          _kMaxSidebarWidth,
                        );
                      });
                    },
                    child: SizedBox(
                      width: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.dividerColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  children: [
                    appBar,
                    Expanded(child: chatContent),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile: keep the Scaffold drawer + AppBar layout.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: chatBackgroundColor,
        drawer: Drawer(
          width: drawerWidth,
          backgroundColor: drawerBackgroundColor,
          child: _buildNavigationContent(
            theme: theme,
            drawerBackgroundColor: drawerBackgroundColor,
          ),
        ),
        appBar: appBar,
        body: chatContent,
      ),
    );
  }
}

/// A two-tab dialog for configuring channel and thread instructions.
class _ScopeConfigDialog extends StatefulWidget {
  const _ScopeConfigDialog({
    required this.isSubSection,
    required this.channelController,
    required this.threadController,
    required this.onSaveChannel,
    required this.onSaveThread,
  });

  final bool isSubSection;
  final TextEditingController channelController;
  final TextEditingController threadController;
  final Future<void> Function(String? value) onSaveChannel;
  final Future<void> Function(String? value) onSaveThread;

  @override
  State<_ScopeConfigDialog> createState() => _ScopeConfigDialogState();
}

class _ScopeConfigDialogState extends State<_ScopeConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_tabController.index == 0) {
        await widget.onSaveChannel(widget.channelController.text);
      } else {
        await widget.onSaveThread(widget.threadController.text);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conversation Config'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Channel'),
                Tab(text: 'Thread'),
              ],
            ),
            const SizedBox(height: BricksSpacing.sm),
            SizedBox(
              height: 180,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Channel tab
                  Padding(
                    padding: const EdgeInsets.only(top: BricksSpacing.sm),
                    child: TextField(
                      controller: widget.channelController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                        hintText:
                            'Describe the broad context or topic for this channel.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  // Thread tab
                  widget.isSubSection
                      ? Padding(
                          padding: const EdgeInsets.only(top: BricksSpacing.sm),
                          child: TextField(
                            controller: widget.threadController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              labelText: 'Instructions',
                              hintText:
                                  'Describe the narrower context for this thread.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(BricksSpacing.sm),
                          child: Text(
                            'Main thread uses channel instructions only.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _isSaving || (_tabController.index == 1 && !widget.isSubSection)
                  ? null
                  : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
