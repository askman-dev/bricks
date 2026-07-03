import 'oauth_token_fragment_stub.dart'
    if (dart.library.html) 'oauth_token_fragment_web.dart' as impl;

Future<String?> consumeOAuthTokenFromFragment() =>
    impl.consumeOAuthTokenFromFragment();
