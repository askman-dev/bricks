import 'package:flutter/material.dart';

/// Screen for browsing and switching between workspaces.
class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workspaces')),
      body: const Center(child: Text('Workspace list – coming soon')),
    );
  }
}
