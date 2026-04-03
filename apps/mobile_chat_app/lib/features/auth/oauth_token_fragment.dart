import 'oauth_token_fragment_stub.dart'
    if (dart.library.html) 'oauth_token_fragment_web.dart' as impl;

/// Returns an OAuth token found in the current URL fragment (if present),
/// and clears that fragment parameter from the URL.
Future<String?> consumeOAuthTokenFromFragment() => impl.consumeOAuthTokenFromFragment();
