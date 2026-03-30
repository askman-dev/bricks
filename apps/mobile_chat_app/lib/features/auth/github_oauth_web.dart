import 'dart:async';
// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:js_interop';

// Minimal BroadcastChannel JS interop for the OAuth callback channel.
// BroadcastChannel delivers messages to all same-origin contexts including
// those isolated by Cross-Origin-Opener-Policy (COOP), making it the most
// reliable path when window.opener is severed.
@JS('BroadcastChannel')
extension type _BroadcastChannel._(JSObject _) implements JSObject {
  external factory _BroadcastChannel(String name);
  external set onmessage(JSFunction? value);
  external void close();
}

@JS()
extension type _BroadcastMessageData._(JSObject _) implements JSObject {
  external JSString? get type;
  external JSString? get token;
}

@JS()
extension type _BroadcastMessageEvent._(JSObject _) implements JSObject {
  external _BroadcastMessageData? get data;
}

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
  _BroadcastChannel? broadcastChannel;
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
    try {
      broadcastChannel?.close();
    } catch (_) {
      // Ignore – the channel may already be closed or unavailable.
    }

    // The popup reference may be neutered by the OAuth provider's COOP headers
    // (in which case popup.closed always reports true and popup.close() is a
    // no-op). Wrap in try-catch to be safe.
    try {
      popup.close();
    } catch (_) {
      // Ignore – the popup proxy may be neutered by COOP and unable to close.
    }

    completer.complete(token);
  }

  // PRIMARY: BroadcastChannel – works even when window.opener is severed by
  // COOP, because BroadcastChannel is origin-scoped, not browsing-context-
  // group-scoped.
  try {
    broadcastChannel = _BroadcastChannel('bricks:github-auth');
    broadcastChannel.onmessage = (JSObject event) {
      try {
        final msg = event as _BroadcastMessageEvent;
        final data = msg.data;
        if (data == null) return;
        final type = data.type?.toDart;
        final token = data.token?.toDart;
        if (type == 'bricks:github-auth' && token != null && token.isNotEmpty) {
          complete(token);
        }
      } catch (_) {
        // Ignore malformed or unexpected message shapes.
      }
    }.toJS;
  } catch (_) {
    // BroadcastChannel unavailable; fall back to postMessage / localStorage.
    broadcastChannel = null;
  }

  // SECONDARY: postMessage from popup (works when window.opener is not severed).
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

  // TERTIARY: localStorage storage event (fallback when BroadcastChannel and
  // postMessage are both unavailable).
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

  // Safety-net poller: checks localStorage on every tick regardless of popup
  // state.  This catches the case where the storage event was not delivered
  // before the popup closed.
  //
  // We intentionally do NOT call complete(null) when popup.closed is true but
  // no token has arrived.  GitHub's COOP headers cause the parent's popup
  // reference to be neutered when the popup navigates to GitHub – after which
  // popup.closed permanently reports true even while the popup is still open.
  // Using popup.closed to infer cancellation therefore produces false positives
  // that abort a live auth flow.  User-initiated cancellation is instead
  // surfaced by the two-minute timeout below.
  popupWatcher = Timer.periodic(const Duration(milliseconds: 250), (_) {
    try {
      final stored = html.window.localStorage['bricks:auth:callback'];
      if (stored != null) {
        try {
          html.window.localStorage.remove('bricks:auth:callback');
        } catch (_) {
          // Ignore removal errors; complete with the token we already read.
        }
        complete(stored);
      }
    } catch (_) {
      // localStorage access itself failed (e.g. storage blocked in private
      // mode).  Rely on BroadcastChannel / postMessage and the timeout below.
    }
  });

  timeoutTimer = Timer(const Duration(minutes: 2), () {
    complete(null);
  });

  return completer.future;
}
