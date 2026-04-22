import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:workspace_fs/workspace_fs.dart';

import 'chat_history_api_service.dart';
import 'chat_message_sort.dart';

import '../auth/auth_service.dart';
import '../agents/agents_screen.dart';
import '../settings/llm_config_service.dart';
import '../settings/settings_screen.dart';
import '../../services/agents_repository_factory.dart';
import 'chat_arbitration.dart';
import 'chat_bot_registry.dart';
import 'chat_task_protocol.dart';
import 'chat_topology.dart';
import 'chat_message.dart';
import 'chat_builtin_agents.dart';
import 'chat_navigation_page.dart';
import 'widgets/composer_bar.dart';
import 'widgets/message_list.dart';

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
  bool _isSending = false;
  bool _isStreaming = false;
  bool _loadingAgents = true;
  bool _loadingLlmConfigs = true;

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
  Set<String> _builtInAgentNames = const {};
  AgentDefinition? _activeAgent;
  final LlmConfigService _llmConfigService = const LlmConfigService();
  List<LlmConfig> _llmConfigs = const [];
  String? _sessionConfigSlotId;
  String? _sessionModelOverride;
  String? _authToken;
  final List<ChatChannel> _channels = [
    ChatChannel(id: 'default', name: '默认频道', isDefault: true),
  ];
  String _activeChannelId = 'default';
  final Map<String, List<ChatSubSection>> _channelSubSections = {
    'default': <ChatSubSection>[],
  };
  final Map<String, DateTime> _subSectionLastMessageAt = {};
  String _activeSubSection = 'main';

  /// Remembers the last-active sub-section id per channel so that switching
  /// back to a previously visited channel restores the correct sub-section.
  final Map<String, String> _lastActiveSubSectionByChannel = {};
  String? _latestCheckpointCursor;
  int _lastSyncedSeq = 0;
  final ChatHistoryApiService _chatHistoryApiService = ChatHistoryApiService();
  StreamSubscription<ChatHistorySnapshot>? _sseSubscription;
  static const Duration _sseReconnectDelay = Duration(seconds: 3);
  final Map<String, ChatRouter> _channelRouters = {};
  final Map<String, ChatRouter> _threadRouters = {};
  int _respondGeneration = 0;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _disconnectSse();
    Timer(const Duration(seconds: 5), _chatHistoryApiService.dispose);
    _currentSubscription?.cancel();
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }
    super.dispose();
  }

  Future<void> _loadAgents() async {
    final repoFuture = createAgentsRepository();
    final llmConfigsFuture = _llmConfigService.fetchConfigs();
    final tokenFuture = AuthService.getToken();

    try {
      final repo = await repoFuture;
      final llmConfigs = await llmConfigsFuture;
      final authToken = await tokenFuture;
      final customDefinitions = await _readAgentDefinitions(repo);
      final mergedDefinitions = _mergeWithBuiltInAgents(customDefinitions);
      List<ChatPersistedScope> persistedScopes = const [];
      List<ChatScopeSetting> scopeSettings = const [];
      List<ChatChannelNameSetting> channelNames = const [];
      if (authToken != null && authToken.isNotEmpty) {
        try {
          persistedScopes = await _chatHistoryApiService.loadScopes(
            token: authToken,
          );
        } catch (e) {
          // Scope hydration is best-effort; a backend failure (e.g. 404 during
          // rollout or transient error) must not block the rest of chat setup.
          debugPrint(
            'loadScopes failed, continuing without scope hydration: $e',
          );
        }
        try {
          scopeSettings = await _chatHistoryApiService.loadScopeSettings(
            token: authToken,
          );
        } catch (e) {
          debugPrint(
            'loadScopeSettings failed, continuing without router hydration: $e',
          );
        }
        try {
          channelNames = await _chatHistoryApiService.loadChannelNames(
            token: authToken,
          );
        } catch (e) {
          debugPrint(
            'loadChannelNames failed, continuing without channel name hydration: $e',
          );
        }
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
      final restoredChannels = _hydrateChannelsFromScopes(persistedScopes);
      final restoredNamedChannels = _applyPersistedChannelNames(
        channels: restoredChannels,
        channelNames: channelNames,
      );
      final restoredSubSections = _hydrateSubSectionsFromScopes(
        persistedScopes,
      );
      final restoredLastSubSectionByChannel =
          _hydrateLastActiveSubSectionByChannel(persistedScopes);
      final restoredChannelRouters = _hydrateChannelRouters(scopeSettings);
      final restoredThreadRouters = _hydrateThreadRouters(scopeSettings);
      final resolvedActiveChannel = _topologyResolver.resolveChannelId(
        channels: restoredChannels,
        requestedChannelId: _activeChannelId,
      );
      final restoredActiveSubSection =
          restoredLastSubSectionByChannel[resolvedActiveChannel] ?? 'main';
      setState(() {
        _agents = mergedDefinitions;
        _builtInAgentNames = mergedDefinitions
            .map((d) => d.name)
            .where(ChatBuiltInAgents.ids.contains)
            .toSet();
        _activeAgent ??=
            mergedDefinitions.isNotEmpty ? mergedDefinitions.first : null;
        _loadingAgents = false;
        _llmConfigs = llmConfigs;
        _sessionConfigSlotId ??=
            llmConfigs.isNotEmpty ? defaultConfig.slotId : null;
        _sessionModelOverride ??=
            llmConfigs.isNotEmpty ? defaultConfig.defaultModel : null;
        _loadingLlmConfigs = false;
        _authToken = authToken;
        _channels
          ..clear()
          ..addAll(restoredNamedChannels);
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
        _activeChannelId = resolvedActiveChannel;
        _activeSubSection = restoredActiveSubSection;
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
      _builtInAgentNames = mergedDefinitions
          .map((d) => d.name)
          .where(ChatBuiltInAgents.ids.contains)
          .toSet();
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

  String _fallbackScopeName(String id, {required String prefix}) {
    final parsedEpoch = int.tryParse(
      id.replaceFirst(RegExp(r'^[a-zA-Z_-]+-'), ''),
    );
    if (parsedEpoch != null && parsedEpoch > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(parsedEpoch);
      String two(int value) => value.toString().padLeft(2, '0');
      return '$prefix-${dt.year}-${two(dt.month)}-${two(dt.day)}-${two(dt.hour)}-${two(dt.minute)}';
    }
    return id;
  }

  List<ChatChannel> _hydrateChannelsFromScopes(
    List<ChatPersistedScope> scopes,
  ) {
    final channelsById = <String, ChatChannel>{
      'default': const ChatChannel(
        id: 'default',
        name: '默认频道',
        isDefault: true,
      ),
    };
    for (final scope in scopes) {
      if (scope.channelId == 'default') continue;
      channelsById.putIfAbsent(
        scope.channelId,
        () => ChatChannel(
          id: scope.channelId,
          name: _fallbackScopeName(scope.channelId, prefix: 'channel'),
          isDefault: false,
        ),
      );
    }
    return channelsById.values.toList(growable: false);
  }

  Map<String, List<ChatSubSection>> _hydrateSubSectionsFromScopes(
    List<ChatPersistedScope> scopes,
  ) {
    final subSections = <String, List<ChatSubSection>>{
      'default': <ChatSubSection>[],
    };
    for (final scope in scopes) {
      final channelSections = subSections.putIfAbsent(
        scope.channelId,
        () => <ChatSubSection>[],
      );
      if (scope.threadId == 'main' ||
          channelSections.any((item) => item.id == scope.threadId)) {
        continue;
      }
      channelSections.add(
        ChatSubSection(
          id: scope.threadId,
          parentChannelId: scope.channelId,
          name: _fallbackScopeName(scope.threadId, prefix: 'sub'),
          createdAt: scope.lastActivityAt ?? DateTime.now(),
        ),
      );
    }
    return subSections;
  }

  List<ChatChannel> _applyPersistedChannelNames({
    required List<ChatChannel> channels,
    required List<ChatChannelNameSetting> channelNames,
  }) {
    if (channelNames.isEmpty) return channels;
    final namesById = <String, String>{
      for (final item in channelNames) item.channelId: item.displayName,
    };
    return channels.map((channel) {
      final displayName = namesById[channel.id];
      if (displayName == null || displayName.trim().isEmpty) {
        return channel;
      }
      return ChatChannel(
        id: channel.id,
        name: displayName,
        isDefault: channel.isDefault,
      );
    }).toList(growable: false);
  }

  Map<String, String> _hydrateLastActiveSubSectionByChannel(
    List<ChatPersistedScope> scopes,
  ) {
    final byChannel = <String, ChatPersistedScope>{};
    for (final scope in scopes) {
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

  void _createChannel() {
    final existingNames =
        _channels.map((item) => item.name.trim().toLowerCase()).toSet();
    _promptChannelName(
      title: '新建频道',
      confirmLabel: '创建',
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
          _latestCheckpointCursor = null;
          _lastSyncedSeq = 0;
        });
        _configureActiveScopeSync();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已创建频道：${channel.name}')));
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
      title: '频道改名',
      confirmLabel: '保存',
      initialValue: existingChannel.name,
      existingNames: existingNames,
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
        final token = _authToken;
        if (token != null && token.isNotEmpty) {
          unawaited(
            _chatHistoryApiService
                .saveChannelName(
              token: token,
              channelId: channelId,
              displayName: name,
            )
                .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Failed to save channel name "$channelId": $error');
            }),
          );
        }
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
    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      unawaited(
        _chatHistoryApiService
            .saveChannelName(
          token: token,
          channelId: channelId,
          displayName: null,
        )
            .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Failed to archive channel "$channelId": $error');
        }),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已归档频道：${channel.name}')),
    );
  }

  Future<void> _promptChannelName({
    required String title,
    required String confirmLabel,
    required Set<String> existingNames,
    required ValueChanged<String> onConfirmed,
    String initialValue = '',
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
              labelText: '频道名',
              hintText: '请输入频道名',
              errorText: errorText,
            ),
            onSubmitted: (_) {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) {
                setDialogState(() => errorText = '频道名不能为空');
                return;
              }
              if (existingNames.contains(trimmed.toLowerCase())) {
                setDialogState(() => errorText = '频道名已存在');
                return;
              }
              Navigator.of(dialogContext).pop(trimmed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => errorText = '频道名不能为空');
                  return;
                }
                if (existingNames.contains(trimmed.toLowerCase())) {
                  setDialogState(() => errorText = '频道名已存在');
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

  ChatSessionScope get _activeScope => ChatSessionScope(
        channelId: _activeChannelId,
        threadId: _activeSubSection,
      );

  String get _sessionIdForScope => _activeScope.sessionId;

  Future<void> _loadMessagesForActiveScope() async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _latestCheckpointCursor = null;
        _lastSyncedSeq = 0;
      });
      _configureActiveScopeSync();
      return;
    }

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
        token: token,
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
    } catch (_) {
      if (!mounted || _isScopeStale()) return;
      setState(() {
        _messages.clear();
        _latestCheckpointCursor = null;
        _lastSyncedSeq = 0;
      });
      _configureActiveScopeSync();
    }
  }

  String _subSectionKey(String channelId, String sectionId) =>
      '$channelId::$sectionId';

  ChatRouter? _explicitThreadRouter({String? channelId, String? threadId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedThreadId = threadId ?? _activeSubSection;
    if (!_isThreadConversation(threadId: resolvedThreadId)) return null;
    return _threadRouters[_subSectionKey(resolvedChannelId, resolvedThreadId)];
  }

  ChatRouter _effectiveRouterForScope({String? channelId, String? threadId}) {
    final resolvedChannelId = channelId ?? _activeChannelId;
    final resolvedThreadId = threadId ?? _activeSubSection;
    return _explicitThreadRouter(
          channelId: resolvedChannelId,
          threadId: resolvedThreadId,
        ) ??
        _channelRouters[resolvedChannelId] ??
        ChatRouter.defaultRoute;
  }

  String _routerLabel(ChatRouter router) {
    switch (router) {
      case ChatRouter.defaultRoute:
        return 'Bricks Default';
      case ChatRouter.openclaw:
        return 'OpenClaw';
    }
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

  String? _sourceFromRespondRouter(String? router) {
    if (router == null || router.isEmpty || router == 'default') return null;
    return 'backend.respond.$router';
  }

  Future<void> _saveChannelRouter(ChatRouter router) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing auth token')));
      return;
    }

    final channelId = _activeChannelId;
    final previous = _channelRouters[channelId];
    setState(() {
      if (router == ChatRouter.defaultRoute) {
        _channelRouters.remove(channelId);
      } else {
        _channelRouters[channelId] = router;
      }
    });
    _configureActiveScopeSync();

    try {
      await _chatHistoryApiService.saveScopeSetting(
        token: token,
        scopeType: ChatScopeType.channel,
        channelId: channelId,
        router: router == ChatRouter.defaultRoute ? null : router,
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
      });
      _configureActiveScopeSync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save channel router: $error')),
      );
    }
  }

  Future<void> _saveThreadRouter(ChatRouter? router) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing auth token')));
      return;
    }

    final channelId = _activeChannelId;
    final threadId = _activeSubSection;
    final key = _subSectionKey(channelId, threadId);
    final previous = _threadRouters[key];
    setState(() {
      if (router == null) {
        _threadRouters.remove(key);
      } else {
        _threadRouters[key] = router;
      }
    });
    _configureActiveScopeSync();

    try {
      await _chatHistoryApiService.saveScopeSetting(
        token: token,
        scopeType: ChatScopeType.thread,
        channelId: channelId,
        threadId: threadId,
        router: router,
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
      });
      _configureActiveScopeSync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save thread router: $error')),
      );
    }
  }

  void _handleRouterMenuSelection(String value) {
    switch (value) {
      case 'channel:default':
        unawaited(_saveChannelRouter(ChatRouter.defaultRoute));
        return;
      case 'channel:openclaw':
        unawaited(_saveChannelRouter(ChatRouter.openclaw));
        return;
      case 'thread:inherit':
        if (!_isThreadConversation()) return;
        unawaited(_saveThreadRouter(null));
        return;
      case 'thread:default':
        if (!_isThreadConversation()) return;
        unawaited(_saveThreadRouter(ChatRouter.defaultRoute));
        return;
      case 'thread:openclaw':
        if (!_isThreadConversation()) return;
        unawaited(_saveThreadRouter(ChatRouter.openclaw));
        return;
    }
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
    final token = _authToken;
    if (token == null || token.isEmpty) return false;
    if (_effectiveRouterForScope() == ChatRouter.openclaw) return true;
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
    final token = _authToken;
    if (token == null || token.isEmpty) return;

    final capturedSessionId = _sessionIdForScope;
    final capturedChannelId = _activeChannelId;
    final capturedSubSection = _activeSubSection;

    _sseSubscription = _chatHistoryApiService
        .listenEvents(
      token: token,
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
      _messages.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    _configureActiveScopeSync();
  }

  void _switchToSubSection(String subSectionId) {
    setState(() {
      _activeSubSection = subSectionId;
      _messages.clear();
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

  void _sendMessage(String text) {
    if (text.trim().isEmpty || _isSending) return;

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
    });

    final token = _authToken;
    final runtimeSettings = _settingsForAgent(agent);
    if (token == null || token.isEmpty) {
      setState(() {
        _isSending = false;
        _isStreaming = false;
      });
      return;
    }

    final generation = ++_respondGeneration;
    _chatHistoryApiService
        .respond(
      token: token,
      taskId: taskId,
      idempotencyKey: idempotencyKey,
      scope: _activeScope,
      userMessageId: userMessageId,
      assistantMessageId: assistantMessageId,
      userMessage: text,
      resolvedBotId: resolvedBotId,
      resolvedSkillId: resolvedSkillId,
      provider: runtimeSettings.provider,
      model: runtimeSettings.model,
      configId: runtimeSettings.configId,
      createdAt: envelope.createdAt,
    )
        .then((result) async {
      if (!mounted) return;
      // Ignore stale completions if stop was pressed after this request started.
      if (generation != _respondGeneration) return;
      final updated = _updateMessageById(
        userMessageId,
        (current) => current.copyWith(
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
    setState(() {});
  }

  Future<void> _showDebugInfoDialog() async {
    final activeParticipants = _participantManager.participants.active;
    final mode = activeParticipants.length > 1 ? 'Arbitration' : 'Direct';
    final activeSubSectionName = _subSectionNameById(_activeSubSection);
    final subSectionLabel = _activeSubSection == 'main'
        ? '主区'
        : (activeSubSectionName ?? _activeSubSection);
    final rows = <({String label, String value})>[
      (label: 'Channel', value: _activeChannelId),
      (label: '子区', value: subSectionLabel),
      (label: 'Session', value: _sessionIdForScope),
      (label: 'Mode', value: mode),
      if (_latestCheckpointCursor != null)
        (label: 'Cursor', value: _latestCheckpointCursor!),
      (label: 'Seq', value: '$_lastSyncedSeq'),
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('信息'),
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
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAgents || _loadingLlmConfigs) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String activeChannelName = '频道';
    for (final item in _channels) {
      if (item.id == _activeChannelId) {
        activeChannelName = item.name;
        break;
      }
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        drawer: Drawer(
          width: MediaQuery.of(context).size.width,
          child: SafeArea(
            child: ChatNavigationPage(
              agents: _agents
                  .map(
                    (agent) => ChatAgentItem(
                      name: agent.name,
                      prompt: agent.systemPrompt,
                      description: agent.description,
                      isBuiltIn: _builtInAgentNames.contains(agent.name),
                    ),
                  )
                  .toList(),
              channels: _channels
                  .map(
                    (item) => ChatChannelItem(
                      id: item.id,
                      name: item.name,
                      isDefault: item.isDefault,
                    ),
                  )
                  .toList(),
              selectedChannelId: _activeChannelId,
              onChannelSelected: _switchChannel,
              onAgentSelected: (agentName) {
                for (final agent in _agents) {
                  if (agent.name == agentName) {
                    _selectAgent(agent);
                    break;
                  }
                }
              },
              onChannelRename: _renameChannel,
              onChannelArchive: _archiveChannel,
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
        ),
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: PopupMenuButton<String>(
            popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
            tooltip: '切换子区',
            onSelected: (value) {
              if (value == '__new__') {
                _createSubSection();
                unawaited(_loadMessagesForActiveScope());
                return;
              }
              _switchToSubSection(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'main',
                child: Text('回到主区'),
              ),
              const PopupMenuItem<String>(
                value: '__new__',
                child: Text('新建子区'),
              ),
              const PopupMenuDivider(),
              ..._activeSubSections.map(
                (item) => PopupMenuItem<String>(
                  value: item.id,
                  child: Text(item.name),
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _activeSubSection == 'main'
                        ? activeChannelName
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
          actions: [
            PopupMenuButton<String>(
              popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
              tooltip: '子区管理',
              onSelected: (value) {
                switch (value) {
                  case '__rename__':
                  case '__archive__':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('功能暂未实现')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: '__rename__',
                  child: Text('分区改名（未实现）'),
                ),
                const PopupMenuItem<String>(
                  value: '__archive__',
                  child: Text('分区存档（未实现）'),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: MessageList(messages: _messages)),
            ComposerBar(
              activeAgent: _activeAgent,
              agents: _agents,
              showRouteAtMarker:
                  _effectiveRouterForScope() == ChatRouter.defaultRoute,
              routerAction: PopupMenuButton<String>(
                popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
                tooltip: 'Router settings',
                onSelected: _handleRouterMenuSelection,
                itemBuilder: (context) {
                  final isThreadConversation = _isThreadConversation();
                  final channelRouter = _channelRouters[_activeChannelId] ??
                      ChatRouter.defaultRoute;
                  final channelRouterLabel = _routerLabel(channelRouter);
                  final explicitThreadRouter = _explicitThreadRouter();
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
                          selected: channelRouter == ChatRouter.defaultRoute,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'channel:openclaw',
                        child: _buildRouterMenuOption(
                          context: context,
                          label: 'OpenClaw',
                          selected: channelRouter == ChatRouter.openclaw,
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
                          sublabel: channelRouterLabel,
                          selected: explicitThreadRouter == null,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'thread:default',
                        child: _buildRouterMenuOption(
                          context: context,
                          label: 'Bricks Default',
                          selected:
                              explicitThreadRouter == ChatRouter.defaultRoute,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'thread:openclaw',
                        child: _buildRouterMenuOption(
                          context: context,
                          label: 'OpenClaw',
                          selected: explicitThreadRouter == ChatRouter.openclaw,
                        ),
                      ),
                    ],
                  ];
                },
                icon: SizedBox.square(
                  dimension: 24,
                  child: Center(
                    child: _effectiveRouterForScope() == ChatRouter.openclaw
                        ? const Text(
                            '🦞',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, height: 1),
                          )
                        : const Icon(Icons.alt_route, size: 20),
                  ),
                ),
              ),
              onAgentSelected: _selectAgent,
              onOpenModelSelection: _openRuntimeModelConfigDialog,
              onShowInfo: _showDebugInfoDialog,
              onSend: _isSending ? null : _sendMessage,
              onStop: _stopStreaming,
              isStreaming: _isStreaming,
            ),
          ],
        ),
      ),
    );
  }
}
