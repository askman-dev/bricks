import 'package:flutter/material.dart';
import 'package:agent_core/agent_core.dart';
import 'chat_message.dart';
import 'widgets/message_list.dart';
import 'widgets/composer_bar.dart';
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

  /// Manages which agents participate and at what probability.
  final ParticipantManager _participantManager = ParticipantManager();

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isSending = true;
    });

    // TODO(chat): wire to AgentSession.sendMessage()
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      // Decide which agents speak proactively after the user message.
      final speakers = _participantManager.decideProactiveSpeakers();

      setState(() {
        _messages.add(
          ChatMessage(role: 'assistant', content: '(stub) Received: $text'),
        );

        // Emit a proactive message for each triggered agent participant.
        for (final agentId in speakers) {
          final participant =
              _participantManager.participants.findById(agentId);
          if (participant == null) continue;
          _messages.add(
            ChatMessage(
              role: 'assistant',
              content: '(stub) ${participant.agentName} responds proactively.',
              agentId: agentId,
              agentName: participant.agentName,
            ),
          );
        }

        _isSending = false;
      });
    });
  }

  void _openSessionSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SessionSettingsPage(coordinator: _participantManager),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bricks'),
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
            onSend: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
