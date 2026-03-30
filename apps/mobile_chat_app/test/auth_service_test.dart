import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthService', () {
    test('isTestMode is false by default in test runs', () {
      expect(AuthService.isTestMode(), isFalse);
    });

    test('getInjectedTestToken is null without dart-define', () {
      expect(AuthService.getInjectedTestToken(), isNull);
    });

    test('getToken falls back to shared preferences when no test token',
        () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'prefs-token'});
      final token = await AuthService.getToken();
      expect(token, equals('prefs-token'));
    });
  });
}
