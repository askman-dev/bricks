import 'dart:async';
// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String?> performGitHubOAuth() async {
  final returnOrigin = Uri.encodeComponent(html.window.location.origin);
  final popup = html.window.open(
    '/api/auth/github?mode=popup&origin=$returnOrigin',
    'github_oauth',
    'width=520,height=720',
  );


  final completer = Completer<String?>();
  late final StreamSubscription<html.MessageEvent> subscription;
  Timer? timeoutTimer;
  Timer? popupWatcher;

  void complete(String? token) {
    if (completer.isCompleted) {
      return;
    }

    timeoutTimer?.cancel();
    popupWatcher?.cancel();
    subscription.cancel();

    if (popup.closed == false) {
      popup.close();
    }

    completer.complete(token);
  }

  subscription = html.window.onMessage.listen((event) {
    if (event.origin != html.window.location.origin) {
      return;
    }

    final data = event.data;
    if (data is! Map) {
      return;
    }

    if (data['type'] == 'bricks:github-auth') {
      final token = data['token'];
      complete(token is String ? token : null);
    }
  });

  popupWatcher = Timer.periodic(const Duration(milliseconds: 250), (_) {
    if (popup.closed == true) {
      complete(null);
    }
  });

  timeoutTimer = Timer(const Duration(minutes: 2), () {
    complete(null);
  });

  return completer.future;
}
