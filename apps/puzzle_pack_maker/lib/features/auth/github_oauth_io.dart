import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_config.dart';
import 'oauth_callback.dart';

const _loginTimeout = Duration(minutes: 5);

Future<String?> performGitHubOAuth() async {
  final appLinks = AppLinks();
  final completer = Completer<String?>();

  late final StreamSubscription<Uri> subscription;
  subscription = appLinks.uriLinkStream.listen(
    (uri) {
      if (completer.isCompleted || !isNativeOAuthCallback(uri)) return;
      completer.complete(extractOAuthTokenFromUri(uri));
    },
    onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(
          GitHubOAuthException('GitHub sign-in callback failed: $error'),
        );
      }
    },
  );

  final launched = await launchUrl(
    _buildGitHubAuthUri(),
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    await subscription.cancel();
    throw const GitHubOAuthException('Could not open GitHub sign-in.');
  }

  try {
    return await completer.future.timeout(_loginTimeout, onTimeout: () => null);
  } finally {
    await subscription.cancel();
  }
}

Uri _buildGitHubAuthUri() {
  final base = Uri.parse(ApiConfig.resolveBaseUrl());
  return base.resolve('/api/auth/github').replace(
    queryParameters: {'return_to': nativeOAuthCallbackUri},
  );
}
