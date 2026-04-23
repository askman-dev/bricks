import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/llm_config_service.dart';
import 'oauth_callback.dart';

class GitHubOAuthException implements Exception {
  const GitHubOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _loginTimeout = Duration(minutes: 5);

Future<String?> performGitHubOAuth() async {
  final appLinks = AppLinks();
  final completer = Completer<String?>();

  late final StreamSubscription<Uri> subscription;
  subscription = appLinks.uriLinkStream.listen(
    (uri) {
      final token = extractOAuthTokenFromUri(uri);
      if (token != null && !completer.isCompleted) {
        completer.complete(token);
      }
    },
    onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(
          GitHubOAuthException('GitHub sign-in callback failed: $error'),
        );
      }
    },
  );

  final bool launched;
  try {
    launched = await launchUrl(
      _buildGitHubAuthUri(),
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    await subscription.cancel();
    throw const GitHubOAuthException('Could not open GitHub sign-in.');
  }

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
  final base = Uri.parse(LlmConfigService.resolveBaseUrl());
  return base.resolve('/api/auth/github').replace(
    queryParameters: {
      'return_to': nativeOAuthCallbackUri,
    },
  );
}
