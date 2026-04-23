import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat_app/features/auth/oauth_callback.dart';

void main() {
  group('OAuth callback parsing', () {
    test('extracts auth token from native callback fragment', () {
      final token = extractOAuthTokenFromUri(
        Uri.parse('bricks://auth/github/callback#auth_token=jwt-token'),
      );

      expect(token, equals('jwt-token'));
    });

    test('extracts auth token from native callback query fallback', () {
      final token = extractOAuthTokenFromUri(
        Uri.parse('bricks://auth/github/callback?auth_token=jwt-token'),
      );

      expect(token, equals('jwt-token'));
    });

    test('ignores unrelated native links', () {
      final token = extractOAuthTokenFromUri(
        Uri.parse('bricks://auth/other/callback#auth_token=jwt-token'),
      );

      expect(token, isNull);
    });

    test('ignores native callback links without tokens', () {
      final token = extractOAuthTokenFromUri(
        Uri.parse('bricks://auth/github/callback'),
      );

      expect(token, isNull);
    });
  });
}
