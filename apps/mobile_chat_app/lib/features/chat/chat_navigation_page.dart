import 'package:flutter/material.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { manageAgents, appSettings, sessions, createChannel }

class ChatChannelItem {
  const ChatChannelItem({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final bool isDefault;
}

/// Navigation content for chat-related routes, intended for use in a
/// [Drawer].
class ChatNavigationPage extends StatelessWidget {
  const ChatNavigationPage({
    super.key,
    required this.onActionSelected,
    required this.channels,
    required this.selectedChannelId,
    this.onChannelSelected,
  });

  final ValueChanged<ChatNavigationAction> onActionSelected;
  final List<ChatChannelItem> channels;
  final String selectedChannelId;
  final ValueChanged<String>? onChannelSelected;

  void _closeNavigation(BuildContext context) {
    Scaffold.of(context).closeDrawer();
  }

  void _selectAction(BuildContext context, ChatNavigationAction action) {
    _closeNavigation(context);
    onActionSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    final selected = channels.any((item) => item.id == selectedChannelId)
        ? selectedChannelId
        : (channels.isNotEmpty ? channels.first.id : null);
    return ListView(
      children: [
        SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              SizedBox(
                width: kToolbarHeight,
                height: kToolbarHeight,
                child: IconButton(
                  onPressed: () => _closeNavigation(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Navigation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () =>
                    _selectAction(context, ChatNavigationAction.appSettings),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
        const ListTile(
          leading: Icon(Icons.chat_bubble_outline),
          title: Text('Current Chat'),
          subtitle: Text('You are here'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.account_tree_outlined),
          title: const Text('Manage Agents'),
          onTap: () =>
              _selectAction(context, ChatNavigationAction.manageAgents),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '频道',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    _selectAction(context, ChatNavigationAction.createChannel),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('新建频道'),
              ),
            ],
          ),
        ),
        if (channels.isEmpty)
          const ListTile(
            title: Text('No channels'),
            subtitle: Text('Create your first channel'),
          )
        else
          ...channels.map((channel) {
            final isSelected = selected == channel.id;
            return ListTile(
              leading: Icon(
                channel.isDefault ? Icons.home_filled : Icons.forum_outlined,
              ),
              title: Text(channel.name),
              subtitle:
                  channel.isDefault ? const Text('Default channel') : null,
              selected: isSelected,
              onTap: () {
                _closeNavigation(context);
                onChannelSelected?.call(channel.id);
              },
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}
