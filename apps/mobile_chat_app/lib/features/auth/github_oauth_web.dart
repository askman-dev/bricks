import 'dart:async';
// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String?> performGitHubOAuth() async {
  // Clear any stale token from a previous incomplete flow.
  try {
    html.window.localStorage.remove('bricks:auth:callback');
  } catch (_) {
    // localStorage may be blocked; continue without clearing.
  }

  final returnOrigin = Uri.encodeComponent(html.window.location.origin);
  final popup = html.window.open(
    '/api/auth/github?mode=popup&origin=$returnOrigin',
    'github_oauth',
    'width=520,height=720',
  );


  final completer = Completer<String?>();
  late final StreamSubscription<html.MessageEvent> subscription;
  late final StreamSubscription<html.StorageEvent> storageSubscription;
  Timer? timeoutTimer;
  Timer? popupWatcher;

  void complete(String? token) {
    if (completer.isCompleted) {
      return;
    }

    timeoutTimer?.cancel();
    popupWatcher?.cancel();
    subscription.cancel();
    storageSubscription.cancel();

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

  storageSubscription = html.window.onStorage.listen((event) {
    if (event.key == 'bricks:auth:callback') {
      final token = event.newValue;
      // Ignore removal/clear events which have a null or empty newValue.
      if (token == null || token.isEmpty) return;
      // Remove before calling complete() so the popupWatcher safety-net check
      // (below) won't find a stale entry and call complete() a second time.
      try {
        html.window.localStorage.remove('bricks:auth:callback');
      } catch (_) {
        // Ignore removal errors; the important part is completing with the token.
      }
      complete(token);
    }
  });

  popupWatcher = Timer.periodic(const Duration(milliseconds: 250), (_) {
    if (popup.closed == true) {
      // The popup may have closed after writing to localStorage but before the
      // storage event was delivered. Check localStorage directly as a safety net.
      try {
        final stored = html.window.localStorage['bricks:auth:callback'];
        if (stored != null) {
          try {
            html.window.localStorage.remove('bricks:auth:callback');
          } catch (_) {
            // Ignore removal errors; complete with the token we already read.
          }
          complete(stored);
        } else {
          complete(null);
        }
      } catch (_) {
        // localStorage access itself failed; complete with null so the caller
        // is not left waiting until the timeout.
        complete(null);
      }
    }
  });

  timeoutTimer = Timer(const Duration(minutes: 2), () {
    complete(null);
  });

  return completer.future;
}
