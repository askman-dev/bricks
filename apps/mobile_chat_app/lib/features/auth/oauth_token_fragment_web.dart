// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String?> consumeOAuthTokenFromFragment() async {
  final hash = html.window.location.hash;
  if (hash.isEmpty || hash == '#') return null;

  final fragment = hash.startsWith('#') ? hash.substring(1) : hash;
  String fragmentPath = '';
  String query = '';

  final queryStart = fragment.indexOf('?');
  if (queryStart >= 0) {
    // e.g. #/chat?auth_token=... or #/path?foo=bar&auth_token=...
    fragmentPath = fragment.substring(0, queryStart);
    query = fragment.substring(queryStart + 1);
  } else if (fragment.contains('=')) {
    // e.g. #auth_token=... or #foo=bar&auth_token=...
    query = fragment;
  } else {
    // Plain hash with no key=value pairs (e.g. #/chat with no query).
    return null;
  }

  Map<String, String> params;
  try {
    params = Map<String, String>.from(Uri.splitQueryString(query));
  } catch (e) {
    // Guard against malformed query strings; startup continues as a no-op.
    return null;
  }

  final token = params['auth_token'];
  if (token == null || token.isEmpty) return null;

  params.remove('auth_token');
  final remainingQuery = Uri(queryParameters: params).query;
  final pathname = html.window.location.pathname ?? '/';
  final search = html.window.location.search ?? '';

  String nextHash = '';
  if (fragmentPath.isNotEmpty && remainingQuery.isNotEmpty) {
    nextHash = '#$fragmentPath?$remainingQuery';
  } else if (fragmentPath.isNotEmpty) {
    nextHash = '#$fragmentPath';
  } else if (remainingQuery.isNotEmpty) {
    nextHash = '#$remainingQuery';
  }

  final nextUrl = '$pathname$search$nextHash';
  html.window.history.replaceState(null, '', nextUrl);
  return token;
}
