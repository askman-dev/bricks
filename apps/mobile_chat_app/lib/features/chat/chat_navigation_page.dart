import 'package:flutter/material.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { manageAgents, appSettings }

/// Navigation content for chat-related routes, intended for use in a
/// [Drawer].
class ChatNavigationPage extends StatelessWidget {
  const ChatNavigationPage({super.key, required this.onActionSelected});

  final ValueChanged<ChatNavigationAction> onActionSelected;

  void _closeNavigation(BuildContext context) {
    Scaffold.of(context).closeDrawer();
  }

  void _selectAction(BuildContext context, ChatNavigationAction action) {
    onActionSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              SizedBox(
                width: kToolbarHeight,
                child: IconButton(
                  onPressed: () => _closeNavigation(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
              Text(
                'Navigation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
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
