import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'oauth_token_fragment.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _testToken = String.fromEnvironment(
    'BRICKS_TEST_TOKEN',
    defaultValue: '',
  );
  static const _testModeFlag = bool.fromEnvironment(
    'BRICKS_TEST_MODE',
    defaultValue: false,
  );

  static Future<void>? _fragmentHydration;

  static bool isTestMode() {
    return !kReleaseMode && (_testModeFlag || _testToken.isNotEmpty);
  }

  static String? getInjectedTestToken() {
    if (!isTestMode() || _testToken.isEmpty) return null;
    return _testToken;
  }

  static Future<String?> getToken() async {
    await _ensureTokenHydratedFromUrlFragment();
    final testToken = getInjectedTestToken();
    if (testToken != null) return testToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> isLoggedIn() async {
    await _ensureTokenHydratedFromUrlFragment();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> _ensureTokenHydratedFromUrlFragment() async {
    final hydration = _fragmentHydration ??= _hydrateFromUrlFragment();
    try {
      await hydration;
    } catch (error) {
      debugPrint('AuthService: fragment hydration error: $error');
      if (identical(_fragmentHydration, hydration)) {
        _fragmentHydration = null;
      }
    }
  }

  static Future<void> _hydrateFromUrlFragment() async {
    final token = await consumeOAuthTokenFromFragment();
    if (token == null || token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
}
