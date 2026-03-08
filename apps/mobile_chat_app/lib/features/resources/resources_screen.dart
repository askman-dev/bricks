import 'package:flutter/material.dart';

/// Screen for browsing and attaching workspace resources.
class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: const Center(child: Text('Resources – coming soon')),
    );
  }
}
