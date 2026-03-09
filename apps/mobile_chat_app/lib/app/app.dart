import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
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
      home: const ChatScreen(),
    );
  }
}
