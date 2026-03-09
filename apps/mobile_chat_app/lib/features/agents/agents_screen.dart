import 'package:flutter/material.dart';

/// Screen for viewing and managing sub-agents.
class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: const Center(child: Text('Agents – coming soon')),
    );
  }
}
