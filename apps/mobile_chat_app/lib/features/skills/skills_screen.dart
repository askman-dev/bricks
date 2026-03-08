import 'package:flutter/material.dart';

/// Screen for browsing and enabling skills.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skills')),
      body: const Center(child: Text('Skills – coming soon')),
    );
  }
}
