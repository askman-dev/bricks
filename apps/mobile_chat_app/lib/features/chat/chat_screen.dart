import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:workspace_fs/workspace_fs.dart';

import 'chat_history_api_service.dart';

import '../auth/auth_service.dart';
import '../settings/llm_config_service.dart';
import '../settings/settings_screen.dart';
import '../../services/agents_repository_factory.dart';
import 'chat_arbitration.dart';
import 'chat_bot_registry.dart';
import 'chat_task_protocol.dart';
import 'chat_topology.dart';
import 'chat_message.dart';
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
  Timer? _persistDebounce;
  Timer? _syncTimer;
  bool _syncInFlight = false;
  static const Duration _syncPollInterval = Duration(seconds: 2);
  static const Duration _syncMaxBackoff = Duration(seconds: 10);
  Duration _nextSyncDelay = _syncPollInterval;
  final Map<String, ChatRouter> _channelRouters = {};
  final Map<String, ChatRouter> _threadRouters = {};
  int _respondGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _cancelSyncPolling(resetDelay: false);
    _doPersistActiveScopeMessages();
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
      final definitions = await _readAgentDefinitions(repo);
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
      _syncParticipants(definitions);
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
        _agents = definitions;
        _activeAgent ??= definitions.isNotEmpty ? definitions.first : null;
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
    return '$prefix-$ms';
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
        _persistActiveScopeMessages();
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
    _cancelSyncPolling();
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
    _cancelSyncPolling();

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

  String _threadRouterMenuLabel(ChatRouter? router) {
    if (router == null) return 'Follow channel';
    return _routerLabel(router);
  }

  String _activeRouterSummary() {
    final effective = _routerLabel(_effectiveRouterForScope());
    final channel = _routerLabel(
      _channelRouters[_activeChannelId] ?? ChatRouter.defaultRoute,
    );
    final thread = _threadRouterMenuLabel(_explicitThreadRouter());
    return 'Router: $effective · Channel $channel · Thread $thread';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Channel router set to ${_routerLabel(router)}'),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thread router set to ${_threadRouterMenuLabel(router)}',
          ),
        ),
      );
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
        unawaited(_saveThreadRouter(null));
        return;
      case 'thread:default':
        unawaited(_saveThreadRouter(ChatRouter.defaultRoute));
        return;
      case 'thread:openclaw':
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

  void _persistActiveScopeMessages({bool immediate = false}) {
    _persistDebounce?.cancel();
    if (immediate) {
      _doPersistActiveScopeMessages();
      return;
    }
    // Debounce to avoid request storms on streaming deltas.
    _persistDebounce = Timer(const Duration(milliseconds: 500), () {
      _doPersistActiveScopeMessages();
    });
  }

  void _doPersistActiveScopeMessages() {
    final token = _authToken;
    if (token == null || token.isEmpty) return;
    unawaited(
      _chatHistoryApiService
          .upsertMessages(token: token, messages: _messages)
          .then((lastSeq) {
        if (!mounted || lastSeq <= 0) return;
        // Only advance the cursor, never move it backwards.
        setState(() {
          if (lastSeq > _lastSyncedSeq) _lastSyncedSeq = lastSeq;
        });
      }).catchError((_) {}),
    );
  }

  bool _hasPendingAssistantTasks() {
    return _messages.any(
      (message) =>
          message.role == 'assistant' &&
          (message.taskState == ChatTaskState.accepted ||
              message.taskState == ChatTaskState.dispatched),
    );
  }

  bool _shouldSyncActiveScope() {
    final token = _authToken;
    if (token == null || token.isEmpty) return false;
    if (_effectiveRouterForScope() == ChatRouter.openclaw) return true;
    return _hasPendingAssistantTasks();
  }

  void _cancelSyncPolling({bool resetDelay = true}) {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (resetDelay) {
      _nextSyncDelay = _syncPollInterval;
    }
  }

  void _scheduleSync(Duration delay) {
    if (_syncTimer != null || _syncInFlight || !_shouldSyncActiveScope()) {
      return;
    }

    _syncTimer = Timer(delay, () {
      _syncTimer = null;
      if (_syncInFlight || !_shouldSyncActiveScope()) {
        return;
      }
      unawaited(_syncActiveScope());
    });
  }

  void _increaseSyncBackoff() {
    final doubledMilliseconds = _nextSyncDelay.inMilliseconds * 2;
    final cappedMilliseconds = doubledMilliseconds.clamp(
      _syncPollInterval.inMilliseconds,
      _syncMaxBackoff.inMilliseconds,
    );
    _nextSyncDelay = Duration(milliseconds: cappedMilliseconds);
  }

  void _configureActiveScopeSync({bool triggerNow = true}) {
    if (!_shouldSyncActiveScope()) {
      _cancelSyncPolling();
      return;
    }
    _scheduleSync(triggerNow ? Duration.zero : _nextSyncDelay);
  }

  ChatTaskState? _normalizedServerTaskState(
    ChatMessage message, {
    ChatTaskState? fallback,
  }) {
    if (message.taskState != null) return message.taskState;
    if (message.role == 'assistant' && message.content.trim().isNotEmpty) {
      return ChatTaskState.completed;
    }
    return fallback;
  }

  ChatMessage _mergeServerMessage(ChatMessage current, ChatMessage incoming) {
    return incoming.copyWith(
      agentId: incoming.agentId ?? current.agentId,
      agentName: incoming.agentName ?? current.agentName,
      idempotencyKey: current.idempotencyKey,
      acknowledgedAt: incoming.acknowledgedAt ?? current.acknowledgedAt,
      checkpointCursor: incoming.checkpointCursor ?? current.checkpointCursor,
      resolvedBotId: incoming.resolvedBotId ?? current.resolvedBotId,
      resolvedSkillId: incoming.resolvedSkillId ?? current.resolvedSkillId,
      arbitrationMode: current.arbitrationMode,
      fallbackToDefaultBot: current.fallbackToDefaultBot,
      decisionReason: current.decisionReason,
      traceId: current.traceId,
      tieDetected: current.tieDetected,
      tieBotIds: current.tieBotIds,
      selectedScore: current.selectedScore,
      candidateScoreSummary: current.candidateScoreSummary,
      isStreaming: false,
      taskState: _normalizedServerTaskState(
        incoming,
        fallback: current.taskState,
      ),
    );
  }

  int _compareChatMessages(ChatMessage a, ChatMessage b) {
    final aTime = a.createdAt ?? a.timestamp;
    final bTime = b.createdAt ?? b.timestamp;
    final byTime = aTime.compareTo(bTime);
    if (byTime != 0) return byTime;
    if (a.role != b.role) {
      if (a.role == 'user') return -1;
      if (b.role == 'user') return 1;
    }
    return (a.messageId ?? '').compareTo(b.messageId ?? '');
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
        taskState: _normalizedServerTaskState(message),
      );
      final messageId = normalized.messageId;
      if (messageId != null && byId.containsKey(messageId)) {
        final index = byId[messageId]!;
        merged[index] = _mergeServerMessage(merged[index], normalized);
        continue;
      }
      merged.add(normalized);
      if (messageId != null && messageId.isNotEmpty) {
        byId[messageId] = merged.length - 1;
      }
    }

    merged.sort(_compareChatMessages);
    return merged;
  }

  Future<void> _syncActiveScope() async {
    if (_syncInFlight) return;
    final token = _authToken;
    if (token == null || token.isEmpty) return;

    final capturedSessionId = _sessionIdForScope;
    final capturedChannelId = _activeChannelId;
    final capturedSubSection = _activeSubSection;
    _syncInFlight = true;
    var syncFailed = false;
    try {
      final snapshot = await _chatHistoryApiService.sync(
        token: token,
        sessionId: capturedSessionId,
        afterSeq: _lastSyncedSeq,
      );
      if (!mounted || _sessionIdForScope != capturedSessionId) return;
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
        channelId: capturedChannelId,
        subSection: capturedSubSection,
      );
    } catch (error) {
      syncFailed = true;
      debugPrint('chat scope sync failed: $error');
    } finally {
      _syncInFlight = false;
      if (mounted && _sessionIdForScope == capturedSessionId) {
        if (syncFailed) {
          _increaseSyncBackoff();
        } else {
          _nextSyncDelay = _syncPollInterval;
        }
        _configureActiveScopeSync(triggerNow: false);
      }
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
      _messages.clear();
      _latestCheckpointCursor = null;
      _lastSyncedSeq = 0;
    });
    _persistActiveScopeMessages();
    _configureActiveScopeSync();
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
    _persistActiveScopeMessages();
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
    final shouldPersistImmediately =
        normalized.role == 'user' || (!normalized.isStreaming);
    _persistActiveScopeMessages(immediate: shouldPersistImmediately);
    return _messages.length - 1;
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
    _persistActiveScopeMessages();

    final scoreSummary = arbitration.candidateScores
        .map((item) => '${item.botId}:${item.score.toStringAsFixed(2)}')
        .join(', ');
    _appendMessage(
      ChatMessage(
        role: 'user',
        content: text,
        taskId: taskId,
        taskState: ChatTaskState.accepted,
        idempotencyKey: idempotencyKey,
        createdAt: envelope.createdAt,
        acknowledgedAt: ack.acceptedAt,
        checkpointCursor: ack.checkpointCursor,
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
      ),
    );
    final agentMessageIndex = _appendMessage(
      ChatMessage(
        role: 'assistant',
        content: '',
        agentId: resolvedBotId,
        agentName: resolvedBotId,
        isStreaming: true,
        taskId: taskId,
        taskState: ChatTaskState.accepted,
        idempotencyKey: idempotencyKey,
        createdAt: envelope.createdAt,
        acknowledgedAt: ack.acceptedAt,
        checkpointCursor: ack.checkpointCursor,
        sessionId: envelope.sessionId,
        threadId: envelope.threadId,
        resolvedBotId: resolvedBotId,
        resolvedSkillId: resolvedSkillId,
        arbitrationMode: arbitrationMode,
        fallbackToDefaultBot: arbitration.fallbackToDefaultBot,
        tieDetected: arbitration.tieDetected,
        tieBotIds: arbitration.tieBotIds,
        selectedScore: arbitration.selectedScore,
        candidateScoreSummary: scoreSummary.isEmpty ? null : scoreSummary,
        decisionReason: arbitration.reason,
        traceId: arbitrationMode ? traceId : null,
      ),
    );

    setState(() {
      _isSending = true;
      _isStreaming = true;
    });

    final token = _authToken;
    final runtimeSettings = _settingsForAgent(agent);
    if (token == null || token.isEmpty) {
      if (mounted && agentMessageIndex < _messages.length) {
        setState(() {
          _messages[agentMessageIndex] = _messages[agentMessageIndex].copyWith(
            content: 'Error: Missing auth token',
            isStreaming: false,
            taskState: ChatTaskState.failed,
          );
          _isSending = false;
          _isStreaming = false;
        });
      }
      return;
    }

    final generation = ++_respondGeneration;
    _chatHistoryApiService
        .respond(
      token: token,
      taskId: taskId,
      idempotencyKey: idempotencyKey,
      scope: _activeScope,
      userMessageId: _messages[agentMessageIndex - 1].messageId!,
      assistantMessageId: _messages[agentMessageIndex].messageId!,
      userMessage: text,
      resolvedBotId: resolvedBotId,
      resolvedSkillId: resolvedSkillId,
      provider: runtimeSettings.provider,
      model: runtimeSettings.model,
      configId: runtimeSettings.configId,
      createdAt: envelope.createdAt,
    )
        .then((result) async {
      if (!mounted || agentMessageIndex >= _messages.length) return;
      // Ignore stale completions if stop was pressed after this request started.
      if (generation != _respondGeneration) return;
      setState(() {
        _messages[agentMessageIndex] = _messages[agentMessageIndex].copyWith(
          content: result.text,
          isStreaming: false,
          taskState: result.taskState ??
              (result.isAsync
                  ? ChatTaskState.dispatched
                  : ChatTaskState.completed),
        );
        if (result.lastSeqId > _lastSyncedSeq) {
          _lastSyncedSeq = result.lastSeqId;
        }
        if (result.isAsync) {
          _isSending = false;
          _isStreaming = false;
        }
      });
      if (result.isAsync) {
        _configureActiveScopeSync();
        return;
      }
      // Backend already persisted both messages; skip redundant client-side
      // upsert to avoid overwriting backend-only metadata (provider/model/source).
      if (mounted) {
        await _handleProactiveResponses(text);
        setState(() {
          _isSending = false;
          _isStreaming = false;
        });
      }
    }).catchError((error) {
      if (!mounted || agentMessageIndex >= _messages.length) return;
      if (generation != _respondGeneration) return;
      setState(() {
        _messages[agentMessageIndex] = _messages[agentMessageIndex].copyWith(
          content: 'Error: $error',
          isStreaming: false,
          taskState: ChatTaskState.failed,
        );
        _isSending = false;
        _isStreaming = false;
      });
      _persistActiveScopeMessages(immediate: true);
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
      _persistActiveScopeMessages(immediate: true);
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

  PreferredSizeWidget _buildActiveAgentsIndicator() {
    final active = _participantManager.participants.active;
    if (active.isEmpty) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: SizedBox.shrink(),
      );
    }
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(
          left: BricksSpacing.md,
          bottom: BricksSpacing.xs,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: active.map((p) {
              final pct = (p.probability * 100).round();
              return Padding(
                padding: const EdgeInsets.only(right: BricksSpacing.xs),
                child: Chip(
                  avatar: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: Text('${p.agentName} • $pct%'),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
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

    final activeAgentName = _activeAgent?.name;
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
                  .map((agent) => ChatAgentItem(name: agent.name))
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
                }
              },
            ),
          ),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activeChannelName),
              if (activeAgentName != null)
                Text(
                  'Responding as @$activeAgentName',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              Text(
                _activeRouterSummary(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
              tooltip: 'Router settings',
              onSelected: _handleRouterMenuSelection,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    'Channel router · ${_routerLabel(_channelRouters[_activeChannelId] ?? ChatRouter.defaultRoute)}',
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'channel:default',
                  child: Text('Bricks Default'),
                ),
                const PopupMenuItem<String>(
                  value: 'channel:openclaw',
                  child: Text('OpenClaw'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(
                    'Thread router · ${_threadRouterMenuLabel(_explicitThreadRouter())}',
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'thread:inherit',
                  child: Text('Follow channel'),
                ),
                const PopupMenuItem<String>(
                  value: 'thread:default',
                  child: Text('Bricks Default'),
                ),
                const PopupMenuItem<String>(
                  value: 'thread:openclaw',
                  child: Text('OpenClaw'),
                ),
              ],
              icon: const Icon(Icons.alt_route),
            ),
            PopupMenuButton<String>(
              popUpAnimationStyle: BricksTheme.menuPopupAnimationStyle,
              tooltip: 'Sub sections',
              onSelected: (value) {
                if (value == '__new__') {
                  _createSubSection();
                  unawaited(_loadMessagesForActiveScope());
                } else {
                  _cancelSyncPolling();
                  setState(() {
                    _activeSubSection = value;
                    _messages.clear();
                    _latestCheckpointCursor = null;
                    _lastSyncedSeq = 0;
                  });
                  unawaited(_loadMessagesForActiveScope());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(value: 'main', child: Text('回到主区')),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BricksSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.splitscreen_outlined),
                    const SizedBox(width: BricksSpacing.xs),
                    Text(
                      _activeSubSection == 'main'
                          ? '主区'
                          : (_subSectionNameById(_activeSubSection) ??
                              _activeSubSection),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
          bottom: _buildActiveAgentsIndicator(),
        ),
        body: Column(
          children: [
            Expanded(child: MessageList(messages: _messages)),
            ComposerBar(
              activeAgent: _activeAgent,
              agents: _agents,
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
