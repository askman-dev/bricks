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

/// Represents a connected AI node shown in the Nodes tab.
class ChatNodeItem {
  const ChatNodeItem({
    required this.id,
    required this.name,
    this.agents = const [],
  });

  final String id;
  final String name;

  /// Agents connected to this node.
  final List<ChatAgentItem> agents;
}

/// Navigation content for chat-related routes, intended for use in a
/// [Drawer].
///
/// The navigation is split into two tabs: **Channels** (a flat list of
/// channels with a "New Channel" action) and **Nodes** (a flat list of
/// connected AI nodes).
class ChatNavigationPage extends StatefulWidget {
  const ChatNavigationPage({
    super.key,
    required this.onActionSelected,
    required this.channels,
    required this.selectedChannelId,
    this.nodes = const [],
    this.onChannelSelected,
    this.onChannelRename,
    this.onChannelArchive,
    this.onNodeSelected,
    this.onRequestClose,
    this.closeOnChannelSelected = true,
  });

  final ValueChanged<ChatNavigationAction> onActionSelected;
  final List<ChatChannelItem> channels;
  final String selectedChannelId;

  /// Connected AI nodes shown in the Nodes tab.
  final List<ChatNodeItem> nodes;

  final ValueChanged<String>? onChannelSelected;
  final ValueChanged<String>? onChannelRename;
  final ValueChanged<String>? onChannelArchive;

  /// Called when a node is tapped in the Nodes tab. The node's [ChatNodeItem.id]
  /// is passed as the argument. If null, tapping a node navigates to the
  /// [_NodeDetailPage] internally.
  final ValueChanged<String>? onNodeSelected;

  final bool closeOnChannelSelected;

  /// Called when the navigation requests to be closed. This is triggered by
  /// the back arrow, action selections (rename/archive), and channel taps when
  /// [closeOnChannelSelected] is true. On mobile this is left null and the
  /// widget falls back to `Scaffold.of(context).closeDrawer()`; on desktop
  /// callers should wire this to collapse the inline sidebar for explicit close
  /// actions.
  final VoidCallback? onRequestClose;

  @override
  State<ChatNavigationPage> createState() => _ChatNavigationPageState();
}

class _ChatNavigationPageState extends State<ChatNavigationPage>
    with SingleTickerProviderStateMixin {
  static const double _closeSwipeVelocityThreshold = 300;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closeNavigation(BuildContext context) {
    if (widget.onRequestClose != null) {
      widget.onRequestClose!();
    } else {
      Scaffold.of(context).closeDrawer();
    }
  }

  void _selectAction(BuildContext context, ChatNavigationAction action) {
    _closeNavigation(context);
    widget.onActionSelected(action);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final shouldClose = isRtl
        ? velocity > _closeSwipeVelocityThreshold
        : velocity < -_closeSwipeVelocityThreshold;
    if (shouldClose) {
      _closeNavigation(context);
    }
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

  void _openNodeDetail(ChatNodeItem node) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NodeDetailPage(node: node),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.channels;
    final selected = channels.any((item) => item.id == widget.selectedChannelId)
        ? widget.selectedChannelId
        : (channels.isNotEmpty ? channels.first.id : null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Column(
        children: [
        // Header row
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
        // Tab bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Channels'),
            Tab(text: 'Nodes'),
          ],
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Channels tab
              ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _selectAction(
                              context, ChatNavigationAction.createChannel),
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
                          channel.isDefault
                              ? Icons.home_filled
                              : Icons.forum_outlined,
                        ),
                        title: Text(channel.name),
                        subtitle: channel.isDefault
                            ? const Text('Default channel')
                            : null,
                        selected: isSelected,
                        onTap: () {
                          if (widget.closeOnChannelSelected) {
                            _closeNavigation(context);
                          }
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
              ),
              // Nodes tab
              ListView(
                children: [
                  if (widget.nodes.isEmpty)
                    const ListTile(
                      title: Text('No nodes'),
                      subtitle: Text('Connect an AI node to get started'),
                    )
                  else
                    ...widget.nodes.map((node) {
                      return ListTile(
                        leading: const Icon(Icons.memory_outlined),
                        title: Text(node.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (widget.onNodeSelected != null) {
                            widget.onNodeSelected!.call(node.id);
                          } else {
                            _openNodeDetail(node);
                          }
                        },
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail page for a connected AI node showing its Skills and Agents.
class _NodeDetailPage extends StatelessWidget {
  const _NodeDetailPage({required this.node});

  final ChatNodeItem node;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(node.name)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Skills',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const ListTile(
            leading: Icon(Icons.extension_outlined),
            title: Text('Skills coming soon'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Agents',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (node.agents.isEmpty)
            const ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('No agents'),
              subtitle: Text('Connect OpenClaw to see agents'),
            )
          else
            ...node.agents.map((agent) {
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
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
