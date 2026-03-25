import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:chat_domain/chat_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:workspace_fs/workspace_fs.dart';

import '../agents/agents_screen.dart';
import '../session/session_settings_page.dart';
import '../../services/agents_repository_factory.dart';
import 'chat_message.dart';
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
  bool _loadingAgents = true;

  /// Manages which agents participate and at what probability.
  final ParticipantManager _participantManager = ParticipantManager();

  final AgentClient _client = AgentCoreClient();
  final Map<String, AgentSession> _sessions = {};
  AgentsRepository? _agentsRepository;
  List<AgentDefinition> _agents = [];
  AgentDefinition? _activeAgent;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }
    super.dispose();
  }

  Future<void> _loadAgents() async {
    final repo = await createAgentsRepository();
    final definitions = await _readAgentDefinitions(repo);
    if (!mounted) return;
    _agentsRepository = repo;
    _syncParticipants(definitions);
    setState(() {
      _agents = definitions;
      _activeAgent ??= definitions.isNotEmpty ? definitions.first : null;
      _loadingAgents = false;
    });
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

  AgentSettings _settingsForAgent(AgentDefinition? agent) {
    final modelId = _resolveModelId(agent?.model);
    return AgentSettings(
      provider: _providerForModel(modelId),
      model: modelId,
      systemPrompt: agent?.systemPrompt,
    );
  }

  String _providerForModel(String model) {
    if (model.startsWith('gemini')) return 'gemini';
    return 'anthropic';
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

  Future<AgentSession> _sessionForAgent(AgentDefinition? agent) async {
    final key = agent?.name ?? '_default';
    final existing = _sessions[key];
    if (existing != null) return existing;
    final session = _client.createSession(_settingsForAgent(agent));
    _sessions[key] = session;
    return session;
  }

  void _updateMessageContent(int index, String content) {
    if (!mounted || index < 0 || index >= _messages.length) return;
    final current = _messages[index];
    setState(() {
      _messages[index] = ChatMessage(
        role: current.role,
        content: content,
        agentId: current.agentId,
        agentName: current.agentName,
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
    _appendMessage(ChatMessage(role: 'user', content: text));
    final agentMessageIndex = _appendMessage(
      ChatMessage(
        role: 'assistant',
        content: '',
        agentId: agent?.name,
        agentName: agent?.name,
      ),
    );

    setState(() => _isSending = true);

    _sessionForAgent(agent).then((session) async {
      try {
        final stream = session.sendMessage(text);
        await for (final event in stream) {
          if (event is TextDeltaEvent) {
            _updateMessageContent(
              agentMessageIndex,
              _messages[agentMessageIndex].content + event.delta,
            );
          } else if (event is MessageCompleteEvent) {
            _updateMessageContent(agentMessageIndex, event.fullText);
          } else if (event is AgentErrorEvent) {
            _updateMessageContent(
              agentMessageIndex,
              'Error: ${event.message}',
            );
          }
        }
      } catch (e) {
        _updateMessageContent(agentMessageIndex, 'Error: $e');
      } finally {
        if (mounted) {
          await _handleProactiveResponses(text);
          setState(() => _isSending = false);
        }
      }
    });
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
      ),
    );
    final session = await _sessionForAgent(agent);
    try {
      await for (final event in session.sendMessage(userMessage)) {
        if (event is TextDeltaEvent) {
          _updateMessageContent(
            index,
            _messages[index].content + event.delta,
          );
        } else if (event is MessageCompleteEvent) {
          _updateMessageContent(index, event.fullText);
        } else if (event is AgentErrorEvent) {
          _updateMessageContent(index, 'Error: ${event.message}');
        }
      }
    } catch (e) {
      _updateMessageContent(index, 'Error: $e');
    }
  }

  void _openSessionSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SessionSettingsPage(coordinator: _participantManager),
      ),
    ).then((_) => setState(() {}));
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

  @override
  Widget build(BuildContext context) {
    if (_loadingAgents) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activeAgentName = _activeAgent?.name;
    return Scaffold(
      appBar: AppBar(
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
        bottom: _buildActiveAgentsIndicator(),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Manage Agents',
            onPressed: _openAgentsScreen,
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Session Settings',
            onPressed: _openSessionSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: MessageList(messages: _messages)),
          ComposerBar(
            activeAgent: _activeAgent,
            agents: _agents,
            onAgentSelected: _selectAgent,
            onSend: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
