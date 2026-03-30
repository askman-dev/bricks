import 'dart:async';
// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

/// Redirects the current browser tab to the GitHub OAuth consent screen.
///
/// The backend callback page will store the JWT in localStorage (in the
/// format expected by Flutter Web's shared_preferences plugin) and then
/// redirect back to `/`.  The Flutter startup router reads the token from
/// SharedPreferences and navigates to the chat screen automatically.
///
/// This function triggers a full-page navigation. The returned future
/// completes with `null` after initiating navigation so that callers
/// awaiting it do not hang if the navigation is blocked or fails.
Future<String?> performGitHubOAuth() async {
  html.window.location.assign('/api/auth/github');
  // Complete with null immediately after requesting navigation.
  return null;
}
