import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_chat_app/features/chat/text_highlight_api_service.dart';
import 'package:mobile_chat_app/services/authenticated_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('createHighlight sends an authenticated request', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      expect(request.method, equals('POST'));
      expect(request.url.path, equals('/api/resources/highlights'));
      expect(request.headers['Authorization'], equals('Bearer token-1'));
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(request.body) as Map<String, dynamic>, {
        'messageId': 'message-1',
        'selectedText': 'selected text',
        'startOffset': 4,
        'endOffset': 17,
        'color': 'yellow',
      });
      return http.Response(
        jsonEncode({
          'id': 'highlight-1',
          'messageId': 'message-1',
          'selectedText': 'selected text',
          'startOffset': 4,
          'endOffset': 17,
          'color': 'yellow',
          'createdAt': '2026-05-19T00:00:00.000Z',
        }),
        201,
      );
    });
    final service = TextHighlightApiService(
      httpClient: client,
      tokenProvider: () async => 'token-1',
    );

    final created = await service.createHighlight(
      messageId: 'message-1',
      selectedText: 'selected text',
      startOffset: 4,
      endOffset: 17,
    );

    expect(requestCount, equals(1));
    expect(created.id, equals('highlight-1'));
  });

  test('createHighlight reports missing token before a request is sent',
      () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      return http.Response('{}', 500);
    });
    final service = TextHighlightApiService(
      httpClient: client,
      tokenProvider: () async => null,
    );

    await expectLater(
      service.createHighlight(
        messageId: 'message-1',
        selectedText: 'selected text',
      ),
      throwsA(isA<MissingAuthTokenException>()),
    );
    expect(requestCount, equals(0));
  });

  test('listHighlights maps unauthorized responses to auth errors', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], equals('Bearer expired-token'));
      return http.Response('{}', 401);
    });
    final service = TextHighlightApiService(
      httpClient: client,
      tokenProvider: () async => 'expired-token',
    );

    await expectLater(
      service.listHighlights(),
      throwsA(isA<UnauthorizedApiException>()),
    );
  });
}
