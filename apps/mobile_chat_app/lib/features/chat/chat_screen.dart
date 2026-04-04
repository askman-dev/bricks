import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:workspace_fs/workspace_fs.dart';

import '../agents/agents_screen.dart';
import '../auth/auth_service.dart';
import '../settings/llm_config_service.dart';
import '../settings/settings_screen.dart';
import '../../services/agents_repository_factory.dart';
import 'chat_message.dart';
import 'chat_navigation_page.dart';
import 'widgets/composer_bar.dart';
import 'widgets/message_list.dart';

class _ChatChannel {
  const _ChatChannel(
      {required this.id, required this.name, this.isDefault = false});

  final String id;
  final String name;
  final bool isDefault;
}

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
  final Map<String, AgentSession> _sessions = {};
  StreamSubscription<AgentSessionEvent>? _currentSubscription;
  AgentsRepository? _agentsRepository;
  List<AgentDefinition> _agents = [];
  AgentDefinition? _activeAgent;
  final LlmConfigService _llmConfigService = const LlmConfigService();
  List<LlmConfig> _llmConfigs = const [];
  String? _sessionConfigSlotId;
  String? _sessionModelOverride;
  String? _authToken;
  final List<_ChatChannel> _channels = [
    _ChatChannel(id: 'default', name: '默认频道', isDefault: true),
  ];
  String _activeChannelId = 'default';
  final Map<String, List<String>> _channelSubSections = {
    'default': ['main']
  };
  String _activeSubSection = 'main';
  bool _syncingAfterReconnect = false;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
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
      _agentsRepository = repo;
      _syncParticipants(definitions);
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
      });
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

  Future<void> _reloadAgents() async {
    final repo = _agentsRepository ?? await createAgentsRepository();
    final definitions = await _readAgentDefinitions(repo);
    if (!mounted) return;
    _syncParticipants(definitions);
    setState(() {
      _agentsRepository = repo;
      _agents = definitions;
      _activeAgent ??= definitions.isNotEmpty ? definitions.first : null;
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Responding as @${agent.name}')),
    );
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
    var selectedConfig =
        _llmConfigs.firstWhere((cfg) => cfg.slotId == selectedSlot);
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
                    decoration:
                        const InputDecoration(labelText: 'Configuration'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Session now uses $selectedModel')),
    );
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

  String _timestampName({String prefix = 'channel'}) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '$prefix-${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }

  String _newId(String prefix) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$ms';
  }

  void _createChannel() {
    final id = _newId('channel');
    final channel =
        _ChatChannel(id: id, name: _timestampName(), isDefault: false);
    setState(() {
      _channels.add(channel);
      _channelSubSections[id] = ['main'];
      _activeChannelId = id;
      _activeSubSection = 'main';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已创建频道：${channel.name}')));
  }

  void _switchChannel(String channelId) {
    if (_activeChannelId == channelId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _activeChannelId = channelId;
      final subSections = _channelSubSections[channelId] ?? const ['main'];
      _activeSubSection =
          subSections.contains('main') ? 'main' : subSections.first;
    });
    Navigator.of(context).pop();
  }

  List<String> get _activeSubSections {
    return _channelSubSections[_activeChannelId] ?? const ['main'];
  }

  String get _sessionIdForScope =>
      'session:${_activeChannelId}:${_activeSubSection}';

  void _createSubSection() {
    final name = _timestampName(prefix: 'sub');
    setState(() {
      final items =
          _channelSubSections.putIfAbsent(_activeChannelId, () => ['main']);
      items.add(name);
      _activeSubSection = name;
    });
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
    setState(() {
      _messages.add(message);
    });
    return _messages.length - 1;
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty || _isSending) return;

    final agent = _activeAgent;
    final activeParticipants = _participantManager.participants.active;
    final arbitrationMode = activeParticipants.length > 1;
    final resolvedBotId = agent?.name ?? 'ask';
    final taskId = _newId('task');
    final traceId = _newId('trace');
    _appendMessage(
      ChatMessage(
        role: 'user',
        content: text,
        taskId: taskId,
        taskState: ChatTaskState.accepted,
        channelId: _activeChannelId,
        sessionId: _sessionIdForScope,
        threadId: _activeSubSection == 'main' ? null : _activeSubSection,
        resolvedBotId: resolvedBotId,
        resolvedSkillId: resolvedBotId == 'image_generation'
            ? 'image_generation.default'
            : 'ask.default',
        arbitrationMode: arbitrationMode,
        decisionReason: arbitrationMode
            ? 'Judge evaluated ${activeParticipants.length} candidate bots.'
            : 'Direct dispatch (single active bot).',
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
        channelId: _activeChannelId,
        sessionId: _sessionIdForScope,
        threadId: _activeSubSection == 'main' ? null : _activeSubSection,
        resolvedBotId: resolvedBotId,
        resolvedSkillId: resolvedBotId == 'image_generation'
            ? 'image_generation.default'
            : 'ask.default',
        arbitrationMode: arbitrationMode,
        fallbackToDefaultBot: false,
        decisionReason: arbitrationMode
            ? 'Selected highest score.'
            : 'Direct dispatch (single active bot).',
        traceId: arbitrationMode ? traceId : null,
      ),
    );

    setState(() {
      _isSending = true;
      _isStreaming = true;
    });

    _sessionForAgent(agent).then((session) {
      final stream = session.sendMessage(text);
      _currentSubscription = stream.listen(
        (event) {
          if (event is TextDeltaEvent) {
            final current = _messages[agentMessageIndex];
            _updateMessageContent(
              agentMessageIndex,
              current.content + event.delta,
              isStreaming: true,
            );
            if (current.taskState == ChatTaskState.accepted) {
              setState(() {
                _messages[agentMessageIndex] = _messages[agentMessageIndex]
                    .copyWith(taskState: ChatTaskState.dispatched);
              });
            }
          } else if (event is MessageCompleteEvent) {
            if (!mounted || agentMessageIndex >= _messages.length) return;
            setState(() {
              _messages[agentMessageIndex] =
                  _messages[agentMessageIndex].copyWith(
                content: event.fullText,
                isStreaming: false,
                taskState: ChatTaskState.completed,
              );
            });
          } else if (event is AgentErrorEvent) {
            if (!mounted || agentMessageIndex >= _messages.length) return;
            setState(() {
              _messages[agentMessageIndex] =
                  _messages[agentMessageIndex].copyWith(
                content: 'Error: ${event.message}',
                isStreaming: false,
                taskState: ChatTaskState.failed,
                fallbackToDefaultBot: arbitrationMode,
                decisionReason: 'Agent error fallback path triggered.',
              );
            });
          }
        },
        onError: (error) {
          if (!mounted || agentMessageIndex >= _messages.length) return;
          setState(() {
            _messages[agentMessageIndex] =
                _messages[agentMessageIndex].copyWith(
              content: 'Error: $error',
              isStreaming: false,
              taskState: ChatTaskState.failed,
            );
          });
          if (mounted) {
            setState(() {
              _isSending = false;
              _isStreaming = false;
            });
          }
        },
        onDone: () async {
          if (mounted) {
            await _handleProactiveResponses(text);
          }
          if (mounted) {
            setState(() {
              _isSending = false;
              _isStreaming = false;
            });
          }
        },
        cancelOnError: true,
      );
    }).catchError((error) {
      if (mounted && agentMessageIndex < _messages.length) {
        setState(() {
          _messages[agentMessageIndex] = _messages[agentMessageIndex].copyWith(
            content: 'Error: $error',
            isStreaming: false,
            taskState: ChatTaskState.failed,
          );
        });
      }
      if (mounted) {
        setState(() {
          _isSending = false;
          _isStreaming = false;
        });
      }
    });
  }

  void _stopStreaming() {
    _currentSubscription?.cancel();
    _currentSubscription = null;
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

  Future<void> _openAgentsScreen() async {
    final updated = await Navigator.push<AgentDefinition?>(
      context,
      MaterialPageRoute<AgentDefinition?>(builder: (_) => const AgentsScreen()),
    );
    await _reloadAgents();
    if (updated != null) {
      _selectAgent(updated);
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

  Widget _buildContextBar() {
    final activeParticipants = _participantManager.participants.active;
    final mode = activeParticipants.length > 1 ? 'Arbitration' : 'Direct';
    final threadLabel = _activeSubSection == 'main' ? '主区' : _activeSubSection;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BricksSpacing.md,
        vertical: BricksSpacing.xs,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        spacing: BricksSpacing.xs,
        runSpacing: BricksSpacing.xs,
        children: [
          Chip(label: Text('Channel: $_activeChannelId')),
          Chip(label: Text('Thread: $threadLabel')),
          Chip(label: Text('Session: $_sessionIdForScope')),
          Chip(label: Text('Mode: $mode')),
          if (_syncingAfterReconnect) const Chip(label: Text('Syncing…')),
        ],
      ),
    );
  }

  Future<void> _simulateReconnectSync() async {
    if (_messages.isEmpty) return;
    setState(() => _syncingAfterReconnect = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _syncingAfterReconnect = false;
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == 'assistant') {
          _messages[i] = _messages[i].copyWith(isRecovered: true);
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAgents || _loadingLlmConfigs) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activeAgentName = _activeAgent?.name;
    return PopScope(
      canPop: false,
      child: Scaffold(
        drawer: Drawer(
          width: MediaQuery.of(context).size.width,
          child: SafeArea(
            child: ChatNavigationPage(
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
              onActionSelected: (action) {
                switch (action) {
                  case ChatNavigationAction.manageAgents:
                    Navigator.of(context).pop();
                    _openAgentsScreen();
                    break;
                  case ChatNavigationAction.appSettings:
                    Navigator.of(context).pop();
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
              const Text('Bricks'),
              if (activeAgentName != null)
                Text(
                  'Responding as @$activeAgentName',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Sub sections',
              onSelected: (value) {
                if (value == '__new__') {
                  _createSubSection();
                } else {
                  setState(() => _activeSubSection = value);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: '__new__',
                  child: Text('新建子区'),
                ),
                const PopupMenuItem<String>(value: 'main', child: Text('主区')),
                ..._activeSubSections.where((item) => item != 'main').map(
                      (item) =>
                          PopupMenuItem<String>(value: item, child: Text(item)),
                    ),
              ],
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: BricksSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.splitscreen_outlined),
                    const SizedBox(width: BricksSpacing.xs),
                    Text(
                        _activeSubSection == 'main' ? '主区' : _activeSubSection),
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
            _buildContextBar(),
            if (_syncingAfterReconnect)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: MessageList(messages: _messages)),
            ComposerBar(
              activeAgent: _activeAgent,
              agents: _agents,
              onAgentSelected: _selectAgent,
              onOpenModelSelection: _openRuntimeModelConfigDialog,
              onSend: _isSending ? null : _sendMessage,
              onStop: _stopStreaming,
              isStreaming: _isStreaming,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: BricksSpacing.sm),
              child: TextButton.icon(
                onPressed: _simulateReconnectSync,
                icon: const Icon(Icons.sync),
                label: const Text('模拟断线恢复同步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
