// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
// TODO(migrate): Switch from `dart:html` to `package:web` + `dart:js_interop`.
// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String?> performGitHubOAuth() async {
  final returnTo = html.window.location.href;
  final encodedReturnTo = Uri.encodeQueryComponent(returnTo);
  html.window.location.assign('/api/auth/github?return_to=$encodedReturnTo');
  return null;
}
