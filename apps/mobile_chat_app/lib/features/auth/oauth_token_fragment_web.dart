// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String?> consumeOAuthTokenFromFragment() async {
  final hash = html.window.location.hash;
  if (hash.isEmpty || hash == '#') return null;

  final params = Uri.splitQueryString(hash.startsWith('#') ? hash.substring(1) : hash);
  final token = params['auth_token'];
  if (token == null || token.isEmpty) return null;

  params.remove('auth_token');
  final remaining = Uri(queryParameters: params).query;
  final pathname = html.window.location.pathname ?? '/';
  final search = html.window.location.search ?? '';
  final nextUrl = remaining.isEmpty
      ? '$pathname$search'
      : '$pathname$search#$remaining';

  html.window.history.replaceState(null, '', nextUrl);
  return token;
}
