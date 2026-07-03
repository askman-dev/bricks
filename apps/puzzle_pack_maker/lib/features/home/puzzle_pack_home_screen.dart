import 'package:flutter/material.dart';

class PuzzlePackHomeScreen extends StatefulWidget {
  const PuzzlePackHomeScreen({super.key});

  @override
  State<PuzzlePackHomeScreen> createState() => _PuzzlePackHomeScreenState();
}

class _PuzzlePackHomeScreenState extends State<PuzzlePackHomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    _HomeTab(
      title: 'Create',
      icon: Icons.auto_awesome_rounded,
      message: 'Hello world from Create.',
      detail: 'The prompt-to-workbook flow will live here.',
    ),
    _HomeTab(
      title: 'Gallery',
      icon: Icons.grid_view_rounded,
      message: 'Hello world from Gallery.',
      detail: 'Templates, showcases, and shared packs will live here.',
    ),
    _HomeTab(
      title: 'Library',
      icon: Icons.folder_copy_rounded,
      message: 'Hello world from Library.',
      detail: 'Your generated puzzle packs will live here.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_selectedIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Pack Maker'),
      ),
      body: _TabHelloWorld(tab: tab),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: tab.title,
            ),
        ],
      ),
    );
  }
}

class _TabHelloWorld extends StatelessWidget {
  const _TabHelloWorld({required this.tab});

  final _HomeTab tab;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 56, color: colors.primary),
                    const SizedBox(height: 20),
                    Text(
                      tab.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tab.detail,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab {
  const _HomeTab({
    required this.title,
    required this.icon,
    required this.message,
    required this.detail,
  });

  final String title;
  final IconData icon;
  final String message;
  final String detail;
}
