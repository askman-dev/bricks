import 'package:flutter/material.dart';
import 'todo_api_service.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { appSettings, sessions, createChannel, manageAgents }

enum ChatChannelMenuAction { rename, archive }

/// Type filter for the Resources tab.
enum ChatResourceTypeFilter { all, todoList, assetTable, textHighlight }

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

/// Type of resource shown in the Resources tab.
enum ChatResourceType { todoList, assetTable, textHighlight }

/// A resource item shown in the Resources tab.
class ChatResourceItem {
  const ChatResourceItem({
    required this.id,
    required this.type,
    required this.title,
    required this.updatedAt,
    this.notes,
  });

  final String id;
  final ChatResourceType type;
  final String title;
  final DateTime updatedAt;

  /// Optional subtitle shown under the resource title.
  final String? notes;
}

ChatResourceTypeFilter _filterForResourceType(ChatResourceType type) {
  switch (type) {
    case ChatResourceType.todoList:
      return ChatResourceTypeFilter.todoList;
    case ChatResourceType.assetTable:
      return ChatResourceTypeFilter.assetTable;
    case ChatResourceType.textHighlight:
      return ChatResourceTypeFilter.textHighlight;
  }
}

String _labelForResourceFilter(ChatResourceTypeFilter filter) {
  switch (filter) {
    case ChatResourceTypeFilter.all:
      return 'All';
    case ChatResourceTypeFilter.todoList:
      return 'Todo Lists';
    case ChatResourceTypeFilter.assetTable:
      return 'Tables';
    case ChatResourceTypeFilter.textHighlight:
      return 'Highlights';
  }
}

IconData _iconForResourceType(ChatResourceType type) {
  switch (type) {
    case ChatResourceType.todoList:
      return Icons.checklist_outlined;
    case ChatResourceType.assetTable:
      return Icons.table_chart_outlined;
    case ChatResourceType.textHighlight:
      return Icons.format_color_text_outlined;
  }
}

String _labelForResourceType(ChatResourceType type) {
  switch (type) {
    case ChatResourceType.todoList:
      return 'Todo List';
    case ChatResourceType.assetTable:
      return 'Table';
    case ChatResourceType.textHighlight:
      return 'Text Highlight';
  }
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
/// The navigation is split into three tabs: **Channels** (a flat list of
/// channels with a "New Channel" action), **Resources** (a flat list of
/// todo-lists and asset tables), and **Nodes** (a flat list of connected AI
/// nodes).
class ChatNavigationPage extends StatefulWidget {
  const ChatNavigationPage({
    super.key,
    required this.onActionSelected,
    required this.channels,
    required this.selectedChannelId,
    this.nodes = const [],
    this.resources = const [],
    this.onChannelSelected,
    this.onChannelRename,
    this.onChannelArchive,
    this.onNodeSelected,
    this.onResourceSelected,
    this.onRequestClose,
    this.closeOnChannelSelected = true,
    this.todoApiService,
  });

  final ValueChanged<ChatNavigationAction> onActionSelected;
  final List<ChatChannelItem> channels;
  final String selectedChannelId;

  /// Connected AI nodes shown in the Nodes tab.
  final List<ChatNodeItem> nodes;

  /// Todo-lists and asset tables shown in the Resources tab.
  final List<ChatResourceItem> resources;

  final ValueChanged<String>? onChannelSelected;
  final ValueChanged<String>? onChannelRename;
  final ValueChanged<String>? onChannelArchive;

  /// Called when a node is tapped in the Nodes tab. The node's [ChatNodeItem.id]
  /// is passed as the argument. If null, tapping a node navigates to the
  /// [_NodeDetailPage] internally.
  final ValueChanged<String>? onNodeSelected;

  /// Called when a resource is tapped in the Resources tab. The full
  /// [ChatResourceItem] is passed. If null, tapping opens
  /// [_ResourcePreviewPage] internally.
  final ValueChanged<ChatResourceItem>? onResourceSelected;

  final bool closeOnChannelSelected;

  /// Optional service used to fetch todo items inside [_ResourcePreviewPage].
  final TodoApiService? todoApiService;

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
  ChatResourceTypeFilter _resourceFilter = ChatResourceTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  void _openResourcePreview(ChatResourceItem resource) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ResourcePreviewPage(
          resource: resource,
          todoApiService: widget.todoApiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.channels;
    final selected = channels.any((item) => item.id == widget.selectedChannelId)
        ? widget.selectedChannelId
        : (channels.isNotEmpty ? channels.first.id : null);
    final resources = _filteredResources();

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
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
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
              Tab(text: 'Resources'),
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
                            icon:
                                const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('New Channel'),
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
                // Resources tab
                ListView(
                  children: [
                    _ResourceTypeFilterBar(
                      selected: _resourceFilter,
                      onSelected: (filter) {
                        setState(() => _resourceFilter = filter);
                      },
                    ),
                    if (resources.isEmpty)
                      const ListTile(
                        title: Text('No resources'),
                        subtitle: Text('Resources will appear here'),
                      )
                    else
                      ...resources.map((resource) {
                        final notes = resource.notes?.trim();
                        return ListTile(
                          leading: Icon(_iconForResourceType(resource.type)),
                          title: Text(resource.title),
                          subtitle: notes != null && notes.isNotEmpty
                              ? Text(
                                  notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            if (widget.onResourceSelected != null) {
                              widget.onResourceSelected!.call(resource);
                            } else {
                              _openResourcePreview(resource);
                            }
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

  int _compareResources(ChatResourceItem a, ChatResourceItem b) {
    final updatedAtComparison = b.updatedAt.compareTo(a.updatedAt);
    if (updatedAtComparison != 0) {
      return updatedAtComparison;
    }

    final typeComparison = _filterForResourceType(a.type).index.compareTo(
          _filterForResourceType(b.type).index,
        );
    if (typeComparison != 0) {
      return typeComparison;
    }

    return a.id.compareTo(b.id);
  }

  List<ChatResourceItem> _filteredResources() {
    final sorted = List<ChatResourceItem>.from(widget.resources)
      ..sort(_compareResources);
    if (_resourceFilter == ChatResourceTypeFilter.all) {
      return sorted;
    }
    return sorted
        .where((item) => _filterForResourceType(item.type) == _resourceFilter)
        .toList(growable: false);
  }
}

class _ResourceTypeFilterBar extends StatelessWidget {
  const _ResourceTypeFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final ChatResourceTypeFilter selected;
  final ValueChanged<ChatResourceTypeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in ChatResourceTypeFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_labelForResourceFilter(filter)),
                selected: selected == filter,
                onSelected: (_) => onSelected(filter),
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

/// Preview page for a resource item.
///
/// When the resource is a todo-list and [todoApiService] is provided, the page
/// fetches the list's todo items and renders them with their status and
/// creation time.
class _ResourcePreviewPage extends StatefulWidget {
  const _ResourcePreviewPage({
    required this.resource,
    this.todoApiService,
  });

  final ChatResourceItem resource;
  final TodoApiService? todoApiService;

  @override
  State<_ResourcePreviewPage> createState() => _ResourcePreviewPageState();
}

class _ResourcePreviewPageState extends State<_ResourcePreviewPage> {
  List<TodoItem>? _items;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.resource.type == ChatResourceType.todoList) {
      _fetchItems();
    }
  }

  Future<void> _fetchItems() async {
    final service = widget.todoApiService;
    if (service == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await service.listTodos(
        listId: widget.resource.id,
      );
      // Sort a copy: incomplete first (by displayOrder), then completed.
      final items = List<TodoItem>.from(raw)
        ..sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.displayOrder.compareTo(b.displayOrder);
        });
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final isTodoList = resource.type == ChatResourceType.todoList;
    final notes = resource.notes?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(resource.title)),
      body: ListView(
        children: [
          // Type chip row
          ListTile(
            leading: Icon(_iconForResourceType(resource.type)),
            title: Text(_labelForResourceType(resource.type)),
          ),
          if (notes != null && notes.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Notes'),
              subtitle: Text(notes),
            ),
          if (isTodoList) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Items',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Failed to load items'),
                subtitle: Text(
                  _error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchItems,
                ),
              )
            else if (_items == null || _items!.isEmpty)
              const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('No items'),
                subtitle: Text('This list has no todo items yet'),
              )
            else
              ..._items!.map((item) => _TodoItemTile(item: item)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// A single row in the todo-list detail view.
class _TodoItemTile extends StatelessWidget {
  const _TodoItemTile({required this.item});

  final TodoItem item;

  static String _formatDate(DateTime dt) {
    // Format as YYYY-MM-DD HH:mm (local time).
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item.isCompleted
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
        color: item.isCompleted ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        item.title,
        style: item.isCompleted
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).disabledColor,
              )
            : null,
      ),
      subtitle: Text(
        '${item.isCompleted ? "完成" : "待完成"} · 创建于 ${_formatDate(item.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
