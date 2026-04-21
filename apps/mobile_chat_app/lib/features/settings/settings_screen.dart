import 'package:flutter/material.dart';
import '../agents/agents_screen.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'model_settings_screen.dart';
import 'node_settings_screen.dart';
import 'openclaw_token_settings_screen.dart';

/// Screen for managing app and agent settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService.clearToken();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Model Settings'),
            subtitle: const Text('Provider, Base URL, API Key'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ModelSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Manage Agents'),
            subtitle: const Text('Create and edit agent definitions'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AgentsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('节点'),
            subtitle: const Text('管理节点与 Node Token'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NodeSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Openclaw Token'),
            subtitle:
                const Text('Generate plugin token for Openclaw integration'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OpenclawTokenSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
}
