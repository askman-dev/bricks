import 'package:flutter/material.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { manageAgents, appSettings }

/// Full-page navigation for chat-related routes.
class ChatNavigationPage extends StatelessWidget {
  const ChatNavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              leading: Icon(Icons.chat_bubble_outline),
              title: Text('Current Chat'),
              subtitle: Text('You are here'),
            ),
            const ListTile(
              leading: Icon(Icons.history),
              title: Text('Sessions'),
              subtitle: Text('Coming soon'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Manage Agents'),
              onTap: () {
                Navigator.pop(context, ChatNavigationAction.manageAgents);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context, ChatNavigationAction.appSettings);
              },
            ),
          ],
        ),
      ),
    );
  }
}
