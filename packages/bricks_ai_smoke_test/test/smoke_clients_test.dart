import 'dart:convert';
import 'package:bricks_ai_smoke_test/bricks_ai_smoke_test.dart';
import 'package:test/test.dart';
import 'fixtures/mock_http_client.dart';

void main() {
  group('AnthropicSmokeClient', () {
    late MockHttpClient mockHttp;
    late AnthropicEnvConfig config;

    setUp(() {
      mockHttp = MockHttpClient();
      config = AnthropicEnvConfig(
        baseUrl: Uri.parse('https://api.example.com'),
        apiKey: 'test-key',
        model: 'test-model',
      );
    });

    // Case B1: Anthropic request returns output
    test('successful request returns expected result', () async {
      final responseBody = json.encode({
        'content': [
          {'type': 'text', 'text': 'anthropic-ok'}
        ],
        'model': 'test-model',
      });

      mockHttp.addResponse(
        'https://api.example.com/v1/messages',
        MockResponse(statusCode: 200, body: responseBody),
      );

      final client = AnthropicSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isTrue);
      expect(result.provider, equals('anthropic'));
      expect(result.statusCode, equals(200));
      expect(result.outputText, equals('anthropic-ok'));
      expect(result.errorMessage, isNull);

      client.dispose();
    });

    // Case B3: Anthropic exact-response check
    test('returns raw response text without trimming', () async {
      final responseBody = json.encode({
        'content': [
          {'type': 'text', 'text': '  anthropic-ok  \n'}
        ],
      });

      mockHttp.addResponse(
        'https://api.example.com/v1/messages',
        MockResponse(statusCode: 200, body: responseBody),
      );

      final client = AnthropicSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isTrue);
      expect(result.outputText?.trim(), equals('anthropic-ok'));

      client.dispose();
    });

    // Case C1: invalid Anthropic key/url surfaces readable failure
    test('handles 401 authentication error', () async {
      final errorBody = json.encode({
        'error': {'message': 'Invalid API key'}
      });

      mockHttp.addResponse(
        'https://api.example.com/v1/messages',
        MockResponse(statusCode: 401, body: errorBody),
      );

      final client = AnthropicSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isFalse);
      expect(result.provider, equals('anthropic'));
      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('401'));
      expect(result.errorMessage, contains('Invalid API key'));

      client.dispose();
    });

    test('handles 500 server error', () async {
      mockHttp.addResponse(
        'https://api.example.com/v1/messages',
        MockResponse(statusCode: 500, body: 'Internal Server Error'),
      );

      final client = AnthropicSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isFalse);
      expect(result.statusCode, equals(500));
      expect(result.errorMessage, contains('500'));

      client.dispose();
    });

    test('sends correct headers and request body', () async {
      final responseBody = json.encode({
        'content': [
          {'type': 'text', 'text': 'test'}
        ],
      });

      mockHttp.addResponse(
        'https://api.example.com/v1/messages',
        MockResponse(statusCode: 200, body: responseBody),
      );

      final client = AnthropicSmokeClient(config, httpClient: mockHttp);
      await client.sendTestRequest(prompt: 'custom prompt');

      expect(mockHttp.sentRequests, hasLength(1));
      final request = mockHttp.sentRequests.first;

      // Check headers
      expect(request.headers['x-api-key'], equals('test-key'));
      expect(request.headers['anthropic-version'], equals('2023-06-01'));
      expect(request.headers['content-type'], equals('application/json'));

      // Check request body
      final requestBody = json.decode(request.body);
      expect(requestBody['model'], equals('test-model'));
      expect(requestBody['messages'], isA<List>());
      expect(requestBody['messages'][0]['role'], equals('user'));
      expect(requestBody['messages'][0]['content'], equals('custom prompt'));
      expect(requestBody['max_tokens'], equals(1024));

      client.dispose();
    });
  });

  group('GeminiSmokeClient', () {
    late MockHttpClient mockHttp;
    late GeminiEnvConfig config;

    setUp(() {
      mockHttp = MockHttpClient();
      config = GeminiEnvConfig(
        baseUrl: Uri.parse('https://api.example.com'),
        apiKey: 'test-gemini-key',
        model: 'gemini-test-model',
      );
    });

    // Case B2: Gemini request returns output
    test('successful request returns expected result', () async {
      final responseBody = json.encode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'gemini-ok'}
              ]
            }
          }
        ],
      });

      mockHttp.addResponse(
        'https://api.example.com/v1beta/models/gemini-test-model:generateContent?key=test-gemini-key',
        MockResponse(statusCode: 200, body: responseBody),
      );

      final client = GeminiSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isTrue);
      expect(result.provider, equals('gemini'));
      expect(result.statusCode, equals(200));
      expect(result.outputText, equals('gemini-ok'));
      expect(result.errorMessage, isNull);

      client.dispose();
    });

    // Case B4: Gemini exact-response check
    test('returns raw response text without trimming', () async {
      final responseBody = json.encode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '  gemini-ok  \n'}
              ]
            }
          }
        ],
      });

      mockHttp.addResponse(
        'https://api.example.com/v1beta/models/gemini-test-model:generateContent?key=test-gemini-key',
        MockResponse(statusCode: 200, body: responseBody),
      );

      final client = GeminiSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isTrue);
      expect(result.outputText?.trim(), equals('gemini-ok'));

      client.dispose();
    });

    // Case C2: invalid Gemini key/url surfaces readable failure
    test('handles 401 authentication error', () async {
      final errorBody = json.encode({
        'error': {'message': 'API key not valid'}
      });

      mockHttp.addResponse(
        'https://api.example.com/v1beta/models/gemini-test-model:generateContent?key=test-gemini-key',
        MockResponse(statusCode: 401, body: errorBody),
      );

      final client = GeminiSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isFalse);
      expect(result.provider, equals('gemini'));
      expect(result.statusCode, equals(401));
      expect(result.errorMessage, contains('401'));
      expect(result.errorMessage, contains('API key not valid'));

      client.dispose();
    });

    test('handles 500 server error', () async {
      mockHttp.addResponse(
        'https://api.example.com/v1beta/models/gemini-test-model:generateContent?key=test-gemini-key',
        MockResponse(statusCode: 500, body: 'Internal Server Error'),
      );

      final client = GeminiSmokeClient(config, httpClient: mockHttp);
      final result = await client.sendTestRequest();

      expect(result.success, isFalse);
      expect(result.statusCode, equals(500));
      expect(result.errorMessage, contains('500'));

      client.dispose();
    });

    test('sends correct request with API key in query param', () async {
      final responseBody = json.encode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'test'}
              ]
            }
          }
        ],
      });

      mockHttp.addResponse(
        'https://api.example.com/v1beta/models/gemini-test-model:generateContent?key=test-gemini-key',
        MockResponse(statusCode: 200, body: responseBody),
      );

      final client = GeminiSmokeClient(config, httpClient: mockHttp);
      await client.sendTestRequest(prompt: 'custom prompt');

      expect(mockHttp.sentRequests, hasLength(1));
      final request = mockHttp.sentRequests.first;

      // Check URL includes API key as query parameter
      expect(request.url.queryParameters['key'], equals('test-gemini-key'));

      // Check headers
      expect(request.headers['content-type'], equals('application/json'));

      // Check request body
      final requestBody = json.decode(request.body);
      expect(requestBody['contents'], isA<List>());
      expect(requestBody['contents'][0]['parts'], isA<List>());
      expect(requestBody['contents'][0]['parts'][0]['text'],
          equals('custom prompt'));

      client.dispose();
    });
  });
}
