import 'dart:convert';

import 'package:agent_core/src/providers/real_model_gateway.dart';
import 'package:agent_sdk_contract/agent_sdk_contract.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('RealModelGateway', () {
    final gateway = RealModelGateway();

    test('returns synthetic output for test provider', () async {
      const settings = AgentSettings(provider: 'test', model: 'fake');
      final result =
          await gateway.generate(settings: settings, message: 'hello');
      expect(result, equals('Received: hello'));
    });

    test('throws for unsupported providers', () async {
      const settings = AgentSettings(provider: 'unknown', model: 'x');
      await expectLater(
        () => gateway.generate(settings: settings, message: 'hello'),
        throwsA(isA<StateError>()),
      );
    });

    test('unsupported provider error message lists all supported providers',
        () async {
      const settings = AgentSettings(provider: 'unknown', model: 'x');
      try {
        await gateway.generate(settings: settings, message: 'hello');
        fail('Expected StateError');
      } on StateError catch (e) {
        expect(e.message, contains('test'));
        expect(e.message, contains('anthropic'));
        expect(e.message, contains('gemini'));
        expect(e.message, contains('google_ai_studio'));
      }
    });
  });

  group('RealModelGateway Anthropic HTTP', () {
    test('parses successful Anthropic response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, equals('/v1/messages'));
        expect(request.headers['x-api-key'], equals('test-key'));
        expect(request.headers['anthropic-version'], equals('2023-06-01'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], equals('claude-3-haiku'));
        expect(body.containsKey('system'), isFalse);
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Hello from Anthropic!'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(
        httpClient: client,
        environment: {'BRICKS_ANTHROPIC_API_KEY': 'test-key'},
      );
      final result = await gw.generate(
        settings: const AgentSettings(
            provider: 'anthropic', model: 'claude-3-haiku'),
        message: 'hello',
      );
      expect(result, equals('Hello from Anthropic!'));
    });

    test('omits system field when systemPrompt is null', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('system'), isFalse);
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'OK'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(
        httpClient: client,
        environment: {'BRICKS_ANTHROPIC_API_KEY': 'test-key'},
      );
      await gw.generate(
        settings: const AgentSettings(
            provider: 'anthropic', model: 'claude-3-haiku'),
        message: 'hello',
      );
    });

    test('includes system prompt when non-empty', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['system'], equals('Be helpful'));
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'OK'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(
        httpClient: client,
        environment: {'BRICKS_ANTHROPIC_API_KEY': 'test-key'},
      );
      await gw.generate(
        settings: const AgentSettings(
          provider: 'anthropic',
          model: 'claude-3-haiku',
          systemPrompt: 'Be helpful',
        ),
        message: 'hello',
      );
    });

    test('throws on non-2xx Anthropic response', () async {
      final client = MockClient(
          (request) async => http.Response('{"error":"invalid_api_key"}', 401));

      final gw = RealModelGateway(
        httpClient: client,
        environment: {'BRICKS_ANTHROPIC_API_KEY': 'test-key'},
      );
      await expectLater(
        () => gw.generate(
          settings: const AgentSettings(
              provider: 'anthropic', model: 'claude-3-haiku'),
          message: 'hello',
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('401')),
        ),
      );
    });

    test('throws StateError when API key is missing', () async {
      final gw = RealModelGateway(
        // The HTTP client is never reached; error is thrown before the request.
        httpClient: MockClient(
            (request) async => throw StateError('Unexpected HTTP call')),
        environment: {},
      );
      await expectLater(
        () => gw.generate(
          settings: const AgentSettings(
              provider: 'anthropic', model: 'claude-3-haiku'),
          message: 'hello',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('BRICKS_ANTHROPIC_API_KEY'),
          ),
        ),
      );
    });
  });

  group('RealModelGateway backend routing', () {
    test('routes through backend when apiBaseUrl and authToken are set',
        () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), equals('https://backend.example/api/llm/chat'));
        expect(request.headers['authorization'], equals('Bearer tok'));
        expect(request.headers['content-type'], equals('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['provider'], equals('anthropic'));
        expect(body['model'], equals('claude-3-haiku'));
        final messages = body['messages'] as List;
        expect(messages, hasLength(1));
        expect(messages[0]['role'], equals('user'));
        return http.Response(
          jsonEncode({
            'output': [
              {'type': 'text', 'text': 'backend reply'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(httpClient: client, environment: {});
      final result = await gw.generate(
        settings: const AgentSettings(
          provider: 'anthropic',
          model: 'claude-3-haiku',
          apiBaseUrl: 'https://backend.example',
          authToken: 'tok',
        ),
        message: 'hello',
      );
      expect(result, equals('backend reply'));
    });

    test('maps gemini provider to google_ai_studio', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['provider'], equals('google_ai_studio'));
        return http.Response(
          jsonEncode({
            'output': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(httpClient: client, environment: {});
      await gw.generate(
        settings: const AgentSettings(
          provider: 'gemini',
          model: 'gemini-pro',
          apiBaseUrl: 'https://backend.example',
          authToken: 'tok',
        ),
        message: 'hello',
      );
    });

    test('forwards configId when present', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['configId'], equals('cfg-123'));
        return http.Response(
          jsonEncode({
            'output': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(httpClient: client, environment: {});
      await gw.generate(
        settings: const AgentSettings(
          provider: 'anthropic',
          model: 'claude-3-haiku',
          apiBaseUrl: 'https://backend.example',
          authToken: 'tok',
          configId: 'cfg-123',
        ),
        message: 'hello',
      );
    });

    test('omits configId when null', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('configId'), isFalse);
        return http.Response(
          jsonEncode({
            'output': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(httpClient: client, environment: {});
      await gw.generate(
        settings: const AgentSettings(
          provider: 'anthropic',
          model: 'claude-3-haiku',
          apiBaseUrl: 'https://backend.example',
          authToken: 'tok',
        ),
        message: 'hello',
      );
    });

    test('includes system prompt as system message', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        expect(messages, hasLength(2));
        expect(messages[0]['role'], equals('system'));
        expect(messages[0]['content'], equals('Be helpful'));
        expect(messages[1]['role'], equals('user'));
        return http.Response(
          jsonEncode({
            'output': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(httpClient: client, environment: {});
      await gw.generate(
        settings: const AgentSettings(
          provider: 'anthropic',
          model: 'claude-3-haiku',
          apiBaseUrl: 'https://backend.example',
          authToken: 'tok',
          systemPrompt: 'Be helpful',
        ),
        message: 'hello',
      );
    });

    test('omits system message when systemPrompt is null', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        expect(messages, hasLength(1));
        expect(messages[0]['role'], equals('user'));
        return http.Response(
          jsonEncode({
            'output': [
              {'type': 'text', 'text': 'ok'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(httpClient: client, environment: {});
      await gw.generate(
        settings: const AgentSettings(
          provider: 'anthropic',
          model: 'claude-3-haiku',
          apiBaseUrl: 'https://backend.example',
          authToken: 'tok',
        ),
        message: 'hello',
      );
    });

    test('throws on non-2xx backend response', () async {
      final client = MockClient(
          (request) async => http.Response('{"error":"unauthorized"}', 403));

      final gw = RealModelGateway(httpClient: client, environment: {});
      await expectLater(
        () => gw.generate(
          settings: const AgentSettings(
            provider: 'anthropic',
            model: 'claude-3-haiku',
            apiBaseUrl: 'https://backend.example',
            authToken: 'tok',
          ),
          message: 'hello',
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('403')),
        ),
      );
    });

    test('throws when backend response has no text output', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'output': [
                {'type': 'image', 'url': 'https://example.com/img.png'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final gw = RealModelGateway(httpClient: client, environment: {});
      await expectLater(
        () => gw.generate(
          settings: const AgentSettings(
            provider: 'anthropic',
            model: 'claude-3-haiku',
            apiBaseUrl: 'https://backend.example',
            authToken: 'tok',
          ),
          message: 'hello',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('falls through to direct provider when apiBaseUrl is missing',
        () async {
      final gw = RealModelGateway(environment: {});
      final result = await gw.generate(
        settings: const AgentSettings(
          provider: 'test',
          model: 'fake',
          authToken: 'tok',
        ),
        message: 'hello',
      );
      expect(result, equals('Received: hello'));
    });

    test('falls through to direct provider when authToken is missing',
        () async {
      final gw = RealModelGateway(environment: {});
      final result = await gw.generate(
        settings: const AgentSettings(
          provider: 'test',
          model: 'fake',
          apiBaseUrl: 'https://backend.example',
        ),
        message: 'hello',
      );
      expect(result, equals('Received: hello'));
    });
  });

  group('RealModelGateway Gemini HTTP', () {
    test('parses successful Gemini response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('gemini-pro:generateContent'));
        expect(request.url.queryParameters['key'], equals('gemini-key'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('systemInstruction'), isFalse);
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Hello from Gemini!'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final gw = RealModelGateway(
        httpClient: client,
        environment: {'BRICKS_GEMINI_API_KEY': 'gemini-key'},
      );
      final result = await gw.generate(
        settings: const AgentSettings(provider: 'gemini', model: 'gemini-pro'),
        message: 'hello',
      );
      expect(result, equals('Hello from Gemini!'));
    });

    test('throws on non-2xx Gemini response', () async {
      final client = MockClient(
          (request) async => http.Response('{"error":"API_KEY_INVALID"}', 400));

      final gw = RealModelGateway(
        httpClient: client,
        environment: {'BRICKS_GEMINI_API_KEY': 'gemini-key'},
      );
      await expectLater(
        () => gw.generate(
          settings: const AgentSettings(
              provider: 'gemini', model: 'gemini-pro'),
          message: 'hello',
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('400')),
        ),
      );
    });

    test('throws StateError when API key is missing', () async {
      final gw = RealModelGateway(
        // The HTTP client is never reached; error is thrown before the request.
        httpClient: MockClient(
            (request) async => throw StateError('Unexpected HTTP call')),
        environment: {},
      );
      await expectLater(
        () => gw.generate(
          settings: const AgentSettings(
              provider: 'gemini', model: 'gemini-pro'),
          message: 'hello',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('BRICKS_GEMINI_API_KEY'),
          ),
        ),
      );
    });
  });
}
