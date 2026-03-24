import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'chat_message.dart';
import 'widgets/message_list.dart';
import 'widgets/composer_bar.dart';
import 'widgets/agent_selector.dart';
import '../session/session_settings_page.dart';

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
  AgentSession? _currentSession;
  StreamSubscription<AgentSessionEvent>? _streamSubscription;

  /// Manages which agents participate and at what probability.
  final ParticipantManager _participantManager = ParticipantManager();

  /// The currently selected agent ID for processing messages.
  String? _selectedAgentId;

  /// Session name displayed in the top bar.
  final String _sessionName = 'New Session';

  @override
  void initState() {
    super.initState();
    // Initialize with some default agents for testing.
    _participantManager.addParticipant(
      const AgentParticipant(
        agentId: 'notebook',
        agentName: 'Notebook',
        isEnabled: true,
        probability: 0.8,
      ),
    );
    _participantManager.addParticipant(
      const AgentParticipant(
        agentId: 'gemini',
        agentName: 'Gemini',
        isEnabled: true,
        probability: 0.5,
      ),
    );
    // Select the first agent by default.
    if (_participantManager.participants.participants.isNotEmpty) {
      _selectedAgentId =
          _participantManager.participants.participants.first.agentId;
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(role: 'user', content: text);
    setState(() {
      _messages.add(userMessage);
      _isSending = true;
    });

    // Get the selected agent or fall back to the first available.
    final selectedAgent = _selectedAgentId != null
        ? _participantManager.participants.findById(_selectedAgentId!)
        : _participantManager.participants.participants.firstOrNull;

    if (selectedAgent == null) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: 'No agent selected. Please add agents to continue.',
          ),
        );
        _isSending = false;
      });
      return;
    }

    // Create a session with the selected agent's settings.
    final session = AgentCoreClient().createSession(
      const AgentSettings(
        provider: 'stub',
        model: 'stub-model',
        streamEvents: true,
      ),
    );
    _currentSession = session;

    // Create a placeholder streaming message.
    final streamingMessage = ChatMessage(
      role: 'assistant',
      content: '',
      agentId: selectedAgent.agentId,
      agentName: selectedAgent.agentName,
      isStreaming: true,
    );

    setState(() {
      _messages.add(streamingMessage);
      _isSending = false;
      _isStreaming = true;
    });

    // Listen to the stream and update the message content.
    final stream = session.sendMessage(text);
    final buffer = StringBuffer();

    _streamSubscription = stream.listen(
      (event) {
        if (event is TextDeltaEvent) {
          buffer.write(event.delta);
          setState(() {
            // Update the last message with accumulated content.
            if (_messages.isNotEmpty && _messages.last.isStreaming) {
              _messages[_messages.length - 1] = _messages.last.copyWith(
                content: buffer.toString(),
              );
            }
          });
        } else if (event is MessageCompleteEvent) {
          setState(() {
            // Mark the message as complete.
            if (_messages.isNotEmpty && _messages.last.isStreaming) {
              _messages[_messages.length - 1] = _messages.last.copyWith(
                content: event.fullText,
                isStreaming: false,
              );
            }
          });
        } else if (event is RunCompleteEvent) {
          setState(() {
            _isStreaming = false;
            // Ensure the last message is marked as not streaming.
            if (_messages.isNotEmpty && _messages.last.isStreaming) {
              _messages[_messages.length - 1] = _messages.last.copyWith(
                isStreaming: false,
              );
            }
          });

          // After the main response, decide which agents speak proactively.
          final speakers = _participantManager.decideProactiveSpeakers();
          for (final agentId in speakers) {
            // Skip the agent that just responded.
            if (agentId == selectedAgent.agentId) continue;

            final participant =
                _participantManager.participants.findById(agentId);
            if (participant == null) continue;

            setState(() {
              _messages.add(
                ChatMessage(
                  role: 'assistant',
                  content:
                      '(stub) ${participant.agentName} responds proactively.',
                  agentId: agentId,
                  agentName: participant.agentName,
                ),
              );
            });
          }
        } else if (event is AgentErrorEvent) {
          setState(() {
            _isStreaming = false;
            if (_messages.isNotEmpty && _messages.last.isStreaming) {
              _messages[_messages.length - 1] = _messages.last.copyWith(
                content: 'Error: ${event.message}',
                isStreaming: false,
              );
            }
          });
        }
      },
      onError: (error) {
        setState(() {
          _isStreaming = false;
          if (_messages.isNotEmpty && _messages.last.isStreaming) {
            _messages[_messages.length - 1] = _messages.last.copyWith(
              content: 'Error: $error',
              isStreaming: false,
            );
          }
        });
      },
      onDone: () {
        setState(() {
          _isStreaming = false;
        });
      },
    );
  }

  void _stopStreaming() {
    _currentSession?.cancel();
    _streamSubscription?.cancel();
    setState(() {
      _isStreaming = false;
      // Mark the last streaming message as complete with current content.
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          isStreaming: false,
        );
      }
    });
  }

  void _openSessionSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SessionSettingsPage(coordinator: _participantManager),
      ),
    ).then((_) {
      // Refresh the UI after settings change.
      setState(() {
        // If the selected agent was removed, select the first available agent.
        if (_selectedAgentId != null &&
            _participantManager.participants.findById(_selectedAgentId!) ==
                null) {
          _selectedAgentId =
              _participantManager.participants.participants.firstOrNull?.agentId;
        }
      });
    });
  }

  void _onAgentSelected(String agentId) {
    setState(() {
      _selectedAgentId = agentId;
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _currentSession?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Agent selector dropdown.
            AgentSelector(
              selectedAgentId: _selectedAgentId,
              participants: _participantManager.participants.participants,
              onAgentSelected: _onAgentSelected,
            ),
            const SizedBox(width: 8),
            Text(
              '| $_sessionName',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
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
            onSend: _isSending || _isStreaming ? null : _sendMessage,
            onStop: _stopStreaming,
            isStreaming: _isStreaming,
          ),
        ],
      ),
    );
  }
}
