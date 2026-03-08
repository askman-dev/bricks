import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'widgets/message_list.dart';
import 'widgets/composer_bar.dart';

/// The main chat screen – the app's entry point.
///
/// Hosts the [MessageList] and [ComposerBar], and coordinates
/// message sending through the [AgentSession].
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _isSending = true;
    });

    // TODO(chat): wire to AgentSession.sendMessage()
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(role: 'assistant', content: '(stub) Received: $text'),
        );
        _isSending = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bricks')),
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

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});
  final String role;
  final String content;
}
