// ignore_for_file: avoid_web_libraries_in_flutter

// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

import 'oauth_callback.dart';

Future<String?> consumeOAuthTokenFromFragment() async {
  final hash = html.window.location.hash;
  if (hash.isEmpty || hash == '#') return null;

  final fragment = hash.startsWith('#') ? hash.substring(1) : hash;
  String fragmentPath = '';
  String query = '';

  final queryStart = fragment.indexOf('?');
  if (queryStart >= 0) {
    fragmentPath = fragment.substring(0, queryStart);
    query = fragment.substring(queryStart + 1);
  } else if (fragment.contains('=')) {
    query = fragment;
  } else {
    return null;
  }

  late final Map<String, String> params;
  try {
    params = Map<String, String>.from(Uri.splitQueryString(query));
  } catch (_) {
    return null;
  }

  final token = params[oauthTokenParameter];
  if (token == null || token.isEmpty) return null;

  params.remove(oauthTokenParameter);
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

  html.window.history.replaceState(null, '', '$pathname$search$nextHash');
  return token;
}
