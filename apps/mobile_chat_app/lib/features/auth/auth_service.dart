import 'package:shared_preferences/shared_preferences.dart';

/// Manages authentication token storage and retrieval.
class AuthService {
  static const _tokenKey = 'auth_token';

  /// Returns the stored authentication token, or null if absent.
  static Future<String?> getToken() async {
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
