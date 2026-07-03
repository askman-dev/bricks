import 'package:flutter/material.dart';
import 'note_api_service.dart';
import 'todo_api_service.dart';

/// Actions that can be triggered from the chat navigation page.
enum ChatNavigationAction { appSettings, sessions, createChannel, manageAgents }

enum ChatChannelMenuAction { rename, archive }

/// Type filter for the Resources tab.
enum ChatResourceTypeFilter { all, todoList, assetTable, note, textHighlight }

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
enum ChatResourceType { todoList, assetTable, note, textHighlight }

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
    case ChatResourceType.note:
      return ChatResourceTypeFilter.note;
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
    case ChatResourceTypeFilter.note:
      return 'Notes';
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
    case ChatResourceType.note:
      return Icons.description_outlined;
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
    case ChatResourceType.note:
      return 'Note';
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
/// todo-lists, asset tables, notes, and highlights), and **Nodes** (a flat list
/// of connected AI nodes).
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
    this.onResourceChanged,
    this.onRequestClose,
    this.closeOnChannelSelected = true,
    this.todoApiService,
    this.noteApiService,
  });

  final ValueChanged<ChatNavigationAction> onActionSelected;
  final List<ChatChannelItem> channels;
  final String selectedChannelId;

  /// Connected AI nodes shown in the Nodes tab.
  final List<ChatNodeItem> nodes;

  /// Persistent resources shown in the Resources tab.
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

  /// Called after a resource detail edit succeeds so callers can refresh list
  /// summaries and updated timestamps.
  final VoidCallback? onResourceChanged;

  final bool closeOnChannelSelected;

  /// Optional service used to fetch todo items inside [_ResourcePreviewPage].
  final TodoApiService? todoApiService;

  /// Optional service used to fetch full note bodies inside [_ResourcePreviewPage].
  final NoteApiService? noteApiService;

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
              title: const Text('Rename'),
              onTap: () =>
                  Navigator.of(context).pop(ChatChannelMenuAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
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
          noteApiService: widget.noteApiService,
          onResourceChanged: widget.onResourceChanged,
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
                        return ListTile(
                          title: Text(
                            resource.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: _ResourceTypeMeta(resource: resource),
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
                      ? (agent.isBuiltIn ? 'Built-in Agent' : 'Custom Agent')
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

class _ResourceTypeMeta extends StatelessWidget {
  const _ResourceTypeMeta({required this.resource});

  final ChatResourceItem resource;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForResourceType(resource.type),
            size: 14,
            color: textStyle?.color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _labelForResourceType(resource.type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview page for a resource item.
///
/// When the resource is a todo-list or note and the corresponding API service
/// is provided, the page fetches detail content for a read-only preview.
class _ResourcePreviewPage extends StatefulWidget {
  const _ResourcePreviewPage({
    required this.resource,
    this.todoApiService,
    this.noteApiService,
    this.onResourceChanged,
  });

  final ChatResourceItem resource;
  final TodoApiService? todoApiService;
  final NoteApiService? noteApiService;
  final VoidCallback? onResourceChanged;

  @override
  State<_ResourcePreviewPage> createState() => _ResourcePreviewPageState();
}

class _ResourcePreviewPageState extends State<_ResourcePreviewPage> {
  List<TodoItem>? _items;
  TextEditingController? _noteController;
  final Set<String> _updatingTodoIds = {};
  bool _loading = false;
  bool _savingNote = false;
  bool _showNotePreview = false;
  String? _loadError;
  String? _editError;

  @override
  void initState() {
    super.initState();
    if (widget.resource.type == ChatResourceType.todoList) {
      _fetchItems();
    } else if (widget.resource.type == ChatResourceType.note) {
      _noteController =
          TextEditingController(text: widget.resource.notes ?? '');
      _fetchNote();
    }
  }

  @override
  void dispose() {
    _noteController?.dispose();
    super.dispose();
  }

  List<TodoItem> _sortTodoItems(List<TodoItem> raw) {
    return List<TodoItem>.from(raw)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.displayOrder.compareTo(b.displayOrder);
      });
  }

  Future<void> _fetchItems() async {
    final service = widget.todoApiService;
    if (service == null) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final raw = await service.listTodos(
        listId: widget.resource.id,
      );
      final items = _sortTodoItems(raw);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchNote() async {
    final service = widget.noteApiService;
    if (service == null) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final note = await service.getNote(widget.resource.id);
      if (mounted) {
        setState(() {
          _noteController?.text = note.body;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleTodoItem(TodoItem item, bool isCompleted) async {
    final service = widget.todoApiService;
    if (service == null || _updatingTodoIds.contains(item.id)) return;

    setState(() {
      _updatingTodoIds.add(item.id);
      _editError = null;
    });
    try {
      final updated = await service.updateTodo(
        listId: item.listId,
        id: item.id,
        isCompleted: isCompleted,
      );
      if (!mounted) return;
      setState(() {
        final current = _items ?? const <TodoItem>[];
        _items = _sortTodoItems(
          current
              .map((candidate) =>
                  candidate.id == updated.id ? updated : candidate)
              .toList(),
        );
        _updatingTodoIds.remove(item.id);
        _editError = null;
      });
      widget.onResourceChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _editError = e.toString();
        _updatingTodoIds.remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Todo update failed: $e')),
      );
    }
  }

  Future<void> _saveNote() async {
    final service = widget.noteApiService;
    final controller = _noteController;
    if (service == null || controller == null || _savingNote) return;

    setState(() {
      _savingNote = true;
      _editError = null;
    });
    try {
      final updated = await service.updateNote(
        noteId: widget.resource.id,
        body: controller.text,
      );
      if (!mounted) return;
      setState(() {
        _noteController?.text = updated.body;
        _savingNote = false;
        _editError = null;
      });
      widget.onResourceChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _editError = e.toString();
        _savingNote = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note save failed: $e')),
      );
    }
  }

  void _applyMarkdownFormat(_MarkdownFormatAction action) {
    final controller = _noteController;
    if (controller == null) return;

    switch (action) {
      case _MarkdownFormatAction.heading:
        _prefixCurrentLine('## ');
        return;
      case _MarkdownFormatAction.bold:
        _surroundSelection('**', '**', 'bold text');
        return;
      case _MarkdownFormatAction.italic:
        _surroundSelection('*', '*', 'italic text');
        return;
      case _MarkdownFormatAction.unorderedList:
        _prefixCurrentLine('- ');
        return;
      case _MarkdownFormatAction.orderedList:
        _prefixCurrentLine('1. ');
        return;
      case _MarkdownFormatAction.checklist:
        _prefixCurrentLine('- [ ] ');
        return;
      case _MarkdownFormatAction.quote:
        _prefixCurrentLine('> ');
        return;
      case _MarkdownFormatAction.code:
        _insertCodeMarkup();
        return;
    }
  }

  ({String text, int start, int end}) _currentNoteSelection() {
    final controller = _noteController!;
    final text = controller.text;
    final selection = controller.selection;
    final rawStart = selection.isValid ? selection.start : text.length;
    final rawEnd = selection.isValid ? selection.end : text.length;
    final start = rawStart.clamp(0, text.length).toInt();
    final end = rawEnd.clamp(0, text.length).toInt();
    return (
      text: text,
      start: start < end ? start : end,
      end: end > start ? end : start
    );
  }

  void _surroundSelection(
    String prefix,
    String suffix,
    String placeholder,
  ) {
    final controller = _noteController!;
    final selection = _currentNoteSelection();
    final selected = selection.text.substring(selection.start, selection.end);
    final inner = selected.isEmpty ? placeholder : selected;
    final replacement = '$prefix$inner$suffix';
    controller.value = TextEditingValue(
      text: selection.text.replaceRange(
        selection.start,
        selection.end,
        replacement,
      ),
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + inner.length,
      ),
    );
  }

  void _prefixCurrentLine(String prefix) {
    final controller = _noteController!;
    final selection = _currentNoteSelection();
    final searchStart = selection.start == 0 ? 0 : selection.start - 1;
    final lineStart = selection.text.lastIndexOf('\n', searchStart) + 1;
    controller.value = TextEditingValue(
      text: selection.text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(
        offset: selection.end + prefix.length,
      ),
    );
  }

  void _insertCodeMarkup() {
    final controller = _noteController!;
    final selection = _currentNoteSelection();
    final selected = selection.text.substring(selection.start, selection.end);
    final inner = selected.isEmpty ? 'code' : selected;
    final isBlock = inner.contains('\n');
    final prefix = isBlock ? '```\n' : '`';
    final suffix = isBlock ? '\n```' : '`';
    final replacement = '$prefix$inner$suffix';
    controller.value = TextEditingValue(
      text: selection.text.replaceRange(
        selection.start,
        selection.end,
        replacement,
      ),
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + inner.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final isTodoList = resource.type == ChatResourceType.todoList;
    final isNote = resource.type == ChatResourceType.note;
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
          if (_editError != null)
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Update failed'),
              subtitle: Text(
                _editError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
            else if (_loadError != null)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Failed to load items'),
                subtitle: Text(
                  _loadError!,
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
              ..._items!.map(
                (item) => _TodoItemTile(
                  item: item,
                  isUpdating: _updatingTodoIds.contains(item.id),
                  onChanged: widget.todoApiService == null
                      ? null
                      : (value) => _toggleTodoItem(item, value),
                ),
              ),
          ],
          if (isNote) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Body',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Failed to load note'),
                subtitle: Text(
                  _loadError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchNote,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Edit'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.visibility_outlined),
                        label: Text('Preview'),
                      ),
                    ],
                    selected: {_showNotePreview},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _showNotePreview = selection.first;
                      });
                    },
                  ),
                ),
              ),
              if (_showNotePreview)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _MarkdownNotePreview(
                    text: _noteController?.text ?? '',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _MarkdownNoteEditor(
                    controller: _noteController!,
                    onFormat: _applyMarkdownFormat,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: widget.noteApiService == null || _savingNote
                        ? null
                        : _saveNote,
                    icon: _savingNote
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _MarkdownFormatAction {
  heading,
  bold,
  italic,
  unorderedList,
  orderedList,
  checklist,
  quote,
  code,
}

class _MarkdownNoteEditor extends StatelessWidget {
  const _MarkdownNoteEditor({
    required this.controller,
    required this.onFormat,
  });

  final TextEditingController controller;
  final ValueChanged<_MarkdownFormatAction> onFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MarkdownToolbarButton(
                    icon: Icons.title,
                    tooltip: 'Heading',
                    onPressed: () => onFormat(_MarkdownFormatAction.heading),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.format_bold,
                    tooltip: 'Bold',
                    onPressed: () => onFormat(_MarkdownFormatAction.bold),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.format_italic,
                    tooltip: 'Italic',
                    onPressed: () => onFormat(_MarkdownFormatAction.italic),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.format_list_bulleted,
                    tooltip: 'Bulleted list',
                    onPressed: () =>
                        onFormat(_MarkdownFormatAction.unorderedList),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.format_list_numbered,
                    tooltip: 'Numbered list',
                    onPressed: () =>
                        onFormat(_MarkdownFormatAction.orderedList),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.checklist,
                    tooltip: 'Checklist',
                    onPressed: () => onFormat(_MarkdownFormatAction.checklist),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.format_quote,
                    tooltip: 'Quote',
                    onPressed: () => onFormat(_MarkdownFormatAction.quote),
                  ),
                  _MarkdownToolbarButton(
                    icon: Icons.code,
                    tooltip: 'Code',
                    onPressed: () => onFormat(_MarkdownFormatAction.code),
                  ),
                ],
              ),
            ),
          ),
          TextField(
            controller: controller,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownToolbarButton extends StatelessWidget {
  const _MarkdownToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

class _MarkdownNotePreview extends StatelessWidget {
  const _MarkdownNotePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = text.split('\n');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines) _MarkdownPreviewLine(line: line),
          ],
        ),
      ),
    );
  }
}

class _MarkdownPreviewLine extends StatelessWidget {
  const _MarkdownPreviewLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = line.trimLeft();
    final indent = line.length - trimmed.length;
    if (trimmed.isEmpty) {
      return const SizedBox(height: 12);
    }
    if (trimmed.startsWith('# ')) {
      return _PreviewText(
        trimmed.substring(2),
        style: theme.textTheme.titleLarge,
      );
    }
    if (trimmed.startsWith('## ')) {
      return _PreviewText(
        trimmed.substring(3),
        style: theme.textTheme.titleMedium,
      );
    }
    if (trimmed.startsWith('### ')) {
      return _PreviewText(
        trimmed.substring(4),
        style: theme.textTheme.titleSmall,
      );
    }
    if (trimmed.startsWith('> ')) {
      return Padding(
        padding: EdgeInsets.only(left: indent.toDouble()),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _PreviewText(
              trimmed.substring(2),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    final checklist = _stripListPrefix(trimmed, '- [ ] ') ??
        _stripListPrefix(trimmed, '- [x] ') ??
        _stripListPrefix(trimmed, '- [X] ');
    if (checklist != null) {
      return _PreviewListLine(
        indent: indent,
        marker: trimmed.startsWith('- [ ] ') ? '☐' : '☑',
        text: checklist,
      );
    }
    final unordered =
        _stripListPrefix(trimmed, '- ') ?? _stripListPrefix(trimmed, '* ');
    if (unordered != null) {
      return _PreviewListLine(
        indent: indent,
        marker: '•',
        text: unordered,
      );
    }
    final ordered = RegExp(r'^\d+\.\s+').firstMatch(trimmed);
    if (ordered != null) {
      return _PreviewListLine(
        indent: indent,
        marker: trimmed.substring(0, ordered.end).trim(),
        text: trimmed.substring(ordered.end),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: indent.toDouble()),
      child: _PreviewText(trimmed),
    );
  }

  static String? _stripListPrefix(String text, String prefix) {
    return text.startsWith(prefix) ? text.substring(prefix.length) : null;
  }
}

class _PreviewListLine extends StatelessWidget {
  const _PreviewListLine({
    required this.indent,
    required this.marker,
    required this.text,
  });

  final int indent;
  final String marker;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent.toDouble()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: Text(marker)),
          Expanded(child: _PreviewText(text)),
        ],
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style ?? Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// A single row in the todo-list detail view.
class _TodoItemTile extends StatelessWidget {
  const _TodoItemTile({
    required this.item,
    required this.isUpdating,
    this.onChanged,
  });

  final TodoItem item;
  final bool isUpdating;
  final ValueChanged<bool>? onChanged;

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
    return CheckboxListTile(
      value: item.isCompleted,
      onChanged: isUpdating || onChanged == null
          ? null
          : (value) => onChanged!(value ?? false),
      secondary: isUpdating
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
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
        '${item.isCompleted ? "Completed" : "Pending"} · Created ${_formatDate(item.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
