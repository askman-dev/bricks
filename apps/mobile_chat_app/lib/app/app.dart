import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/chat/chat_screen.dart';

/// Root widget for the Bricks app.
class BricksApp extends StatelessWidget {
  const BricksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bricks',
      theme: BricksTheme.light(),
      darkTheme: BricksTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _StartupRouter(),
    );
  }
}

/// Routes to the login screen or the main chat screen depending on whether
/// a token is already stored locally.
class _StartupRouter extends StatelessWidget {
  const _StartupRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const ChatScreen() : const LoginScreen();
      },
    );
  }
}
