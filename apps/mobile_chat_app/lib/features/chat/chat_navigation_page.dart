import 'package:flutter/material.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { appSettings, sessions, createChannel, manageAgents }

enum ChatChannelMenuAction { rename, archive }

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
  const ChatAgentItem({
    required this.name,
    required this.prompt,
    this.description,
    this.isBuiltIn = false,
  });

  final String name;
  final String prompt;
  final String? description;
  final bool isBuiltIn;
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
    this.onAgentSelected,
    this.onChannelRename,
    this.onChannelArchive,
  });

  final ValueChanged<ChatNavigationAction> onActionSelected;
  final List<ChatAgentItem> agents;
  final List<ChatChannelItem> channels;
  final String selectedChannelId;
  final ValueChanged<String>? onChannelSelected;
  final ValueChanged<String>? onAgentSelected;
  final ValueChanged<String>? onChannelRename;
  final ValueChanged<String>? onChannelArchive;

  @override
  State<ChatNavigationPage> createState() => _ChatNavigationPageState();
}

class _ChatNavigationPageState extends State<ChatNavigationPage> {
  bool _skillsExpanded = true;
  bool _agentsExpanded = true;
  bool _channelsExpanded = true;

  void _closeNavigation(BuildContext context) {
    Scaffold.of(context).closeDrawer();
  }

  void _selectAction(BuildContext context, ChatNavigationAction action) {
    _closeNavigation(context);
    widget.onActionSelected(action);
  }

  Future<void> _showChannelMenu(ChatChannelItem channel) async {
    final action = await showModalBottomSheet<ChatChannelMenuAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('改名'),
              onTap: () =>
                  Navigator.of(context).pop(ChatChannelMenuAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('归档'),
              onTap: () =>
                  Navigator.of(context).pop(ChatChannelMenuAction.archive),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ChatChannelMenuAction.rename:
        widget.onChannelRename?.call(channel.id);
        break;
      case ChatChannelMenuAction.archive:
        widget.onChannelArchive?.call(channel.id);
        break;
    }
  }

  Future<void> _showAgentPrompt(ChatAgentItem agent) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AgentPromptPage(
          agent: agent,
          onOpenConfig: () {
            Navigator.of(context).pop();
            _selectAction(context, ChatNavigationAction.manageAgents);
          },
          onStartConversation: () {
            Navigator.of(context).pop();
            _closeNavigation(context);
            widget.onAgentSelected?.call(agent.name);
          },
        ),
      ),
    );
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
                      setState(() => _skillsExpanded = !_skillsExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _skillsExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Skills',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_skillsExpanded)
          const ListTile(
            title: Text('待实现'),
          ),
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
                    child: Row(
                      children: [
                        Icon(
                          _agentsExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Agents',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
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
              (agent) {
                final desc = agent.description?.trim();
                return ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text(agent.name),
                  subtitle: Text(
                    desc == null || desc.isEmpty
                        ? (agent.isBuiltIn ? '内建 Agent' : '自定义 Agent')
                        : desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: agent.isBuiltIn
                      ? const Icon(Icons.lock_outline, size: 18)
                      : null,
                  onTap: () => _showAgentPrompt(agent),
                );
              },
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
                    child: Row(
                      children: [
                        Icon(
                          _channelsExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '频道',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
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
                onLongPress: channel.isDefault
                    ? null
                    : () {
                        _showChannelMenu(channel);
                      },
              );
            }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AgentPromptPage extends StatelessWidget {
  const _AgentPromptPage({
    required this.agent,
    required this.onOpenConfig,
    required this.onStartConversation,
  });

  final ChatAgentItem agent;
  final VoidCallback onOpenConfig;
  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    final trimmedPrompt = agent.prompt.trim();
    final prompt = trimmedPrompt.isEmpty ? '（未配置 Prompt）' : trimmedPrompt;
    return Scaffold(
      appBar: AppBar(title: Text(agent.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prompt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(prompt),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenConfig,
                    child: const Text('修改配置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onStartConversation,
                    child: const Text('发起对话'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
