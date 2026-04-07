import 'package:flutter/material.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { appSettings, sessions, createChannel }

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

class ChatAgentItem {
  const ChatAgentItem({required this.name});

  final String name;
}

/// Navigation content for chat-related routes, intended for use in a
/// [Drawer].
class ChatNavigationPage extends StatefulWidget {
  const ChatNavigationPage({
    super.key,
    required this.onActionSelected,
    required this.agents,
    required this.channels,
    required this.selectedChannelId,
    this.onChannelSelected,
  });

  final ValueChanged<ChatNavigationAction> onActionSelected;
  final List<ChatAgentItem> agents;
  final List<ChatChannelItem> channels;
  final String selectedChannelId;
  final ValueChanged<String>? onChannelSelected;

  @override
  State<ChatNavigationPage> createState() => _ChatNavigationPageState();
}

class _ChatNavigationPageState extends State<ChatNavigationPage> {
  bool _agentsExpanded = true;
  bool _channelsExpanded = true;

  void _closeNavigation(BuildContext context) {
    Scaffold.of(context).closeDrawer();
  }

  void _selectAction(BuildContext context, ChatNavigationAction action) {
    _closeNavigation(context);
    widget.onActionSelected(action);
  }

  void _showNotImplementedToast() {
    final messenger = ScaffoldMessenger.of(context);
    Scaffold.of(context).closeDrawer();
    messenger.hideCurrentSnackBar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('未开发的功能')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.channels;
    final agents = widget.agents;
    final selected = channels.any((item) => item.id == widget.selectedChannelId)
        ? widget.selectedChannelId
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _agentsExpanded = !_agentsExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Agents',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showNotImplementedToast,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('配置'),
              ),
            ],
          ),
        ),
        if (_agentsExpanded)
          if (agents.isEmpty)
            const ListTile(
              title: Text('在设置中新建 Agents'),
            )
          else
            ...agents.map(
              (agent) => ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: Text(agent.name),
              ),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      setState(() => _channelsExpanded = !_channelsExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '频道',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
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
        if (_channelsExpanded)
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
                  widget.onChannelSelected?.call(channel.id);
                },
              );
            }),
        const SizedBox(height: 24),
      ],
    );
  }
}
