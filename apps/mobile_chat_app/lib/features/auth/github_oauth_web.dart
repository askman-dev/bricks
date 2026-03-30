// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<String?> performGitHubOAuth() async {
  final returnOrigin = Uri.encodeComponent(html.window.location.origin);
  html.window.open(
    '/api/auth/github?mode=popup&origin=$returnOrigin',
    'github_oauth',
    'width=520,height=720',
  );

  final completer = Completer<String?>();
  late final StreamSubscription<html.MessageEvent> subscription;
  subscription = html.window.onMessage.listen((event) {
    final data = event.data;
    if (data is! Map) {
      return;
    }

    if (data['type'] == 'bricks:github-auth' && data['token'] is String) {
      completer.complete(data['token'] as String);
      subscription.cancel();
    }
  });

  Timer(const Duration(minutes: 2), () {
    if (!completer.isCompleted) {
      completer.complete(null);
      subscription.cancel();
    }
  });

  return completer.future;
}
