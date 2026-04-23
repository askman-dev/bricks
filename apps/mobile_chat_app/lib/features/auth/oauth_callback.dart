const nativeOAuthCallbackScheme = 'bricks';
const nativeOAuthCallbackHost = 'auth';
const nativeOAuthCallbackPath = '/github/callback';
const nativeOAuthCallbackUri = 'bricks://auth/github/callback';
const oauthTokenParameter = 'auth_token';

class GitHubOAuthException implements Exception {
  const GitHubOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isNativeOAuthCallback(Uri uri) {
  return uri.scheme == nativeOAuthCallbackScheme &&
      uri.host == nativeOAuthCallbackHost &&
      uri.path == nativeOAuthCallbackPath;
}

String? extractOAuthTokenFromUri(Uri uri) {
  if (!isNativeOAuthCallback(uri)) return null;

  final queryToken = uri.queryParameters[oauthTokenParameter];
  if (queryToken != null && queryToken.isNotEmpty) {
    return queryToken;
  }

  final fragment = uri.fragment;
  if (fragment.isEmpty) return null;

  try {
    final fragmentParams = Uri.splitQueryString(fragment);
    final fragmentToken = fragmentParams[oauthTokenParameter];
    if (fragmentToken != null && fragmentToken.isNotEmpty) {
      return fragmentToken;
    }
  } catch (_) {
    return null;
  }

  return null;
}
