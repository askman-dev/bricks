import 'github_oauth_stub.dart'
    if (dart.library.html) 'github_oauth_web.dart' as impl;

Future<String?> performGitHubOAuth() => impl.performGitHubOAuth();
