import 'package:flutter/material.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { manageAgents, appSettings }

/// Navigation content for chat-related routes, intended for use in a
/// [Drawer] or other side navigation container.
class ChatNavigationPage extends StatelessWidget {
  const ChatNavigationPage({super.key, this.onActionSelected});

  final ValueChanged<ChatNavigationAction>? onActionSelected;

  void _selectAction(BuildContext context, ChatNavigationAction action) {
    final callback = onActionSelected;
    if (callback != null) {
      callback(action);
      return;
    }
    Navigator.pop(context, action);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Navigation'),
        ),
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
          onTap: () =>
              _selectAction(context, ChatNavigationAction.manageAgents),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () => _selectAction(context, ChatNavigationAction.appSettings),
        ),
      ],
    );
  }
}
