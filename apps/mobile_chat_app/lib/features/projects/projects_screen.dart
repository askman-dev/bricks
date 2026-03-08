import 'package:flutter/material.dart';

/// Screen for browsing and opening projects in the current workspace.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: const Center(child: Text('Project list – coming soon')),
    );
  }
}
