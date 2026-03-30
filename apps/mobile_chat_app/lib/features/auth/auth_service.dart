import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Manages authentication token storage and retrieval.
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

  /// Returns true when running in a non-release build with test auth enabled.
  static bool isTestMode() {
    return !kReleaseMode && (_testModeFlag || _testToken.isNotEmpty);
  }

  /// Returns the injected test token, or null when unavailable.
  static String? getInjectedTestToken() {
    if (!isTestMode() || _testToken.isEmpty) {
      return null;
    }
    return _testToken;
  }

  /// Returns the stored authentication token, or null if absent.
  static Future<String?> getToken() async {
    final testToken = getInjectedTestToken();
    if (testToken != null) {
      return testToken;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Persists [token] in local storage.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Removes the stored authentication token.
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Returns true when a token is present in local storage.
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
