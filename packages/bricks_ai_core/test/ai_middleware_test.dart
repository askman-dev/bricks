import 'package:bricks_ai_core/bricks_ai_core.dart';
import 'package:test/test.dart';

import 'fixtures/fake_ai_model.dart';
import 'fixtures/fake_stream_outputs.dart';

/// A middleware that records the inbound request and all outbound events,
/// optionally mutating the request before forwarding.
class RecordingMiddleware implements AiMiddleware {
  RecordingMiddleware({this.requestMutation});

  /// Optional function to transform the request before forwarding.
  final AiRequest Function(AiRequest)? requestMutation;

  AiRequest? recordedRequest;
  final List<AiStreamEvent> recordedEvents = [];

  @override
  Future<AiGenerateResult> interceptGenerate(
    AiRequest request,
    Future<AiGenerateResult> Function(AiRequest request) next,
  ) async {
    recordedRequest = request;
    final forwarded =
        requestMutation != null ? requestMutation!(request) : request;
    return next(forwarded);
  }

  @override
  Stream<AiStreamEvent> interceptStream(
    AiRequest request,
    Stream<AiStreamEvent> Function(AiRequest request) next,
  ) async* {
    recordedRequest = request;
    final forwarded =
        requestMutation != null ? requestMutation!(request) : request;
    await for (final event in next(forwarded)) {
      recordedEvents.add(event);
      yield event;
    }
  }
}

void main() {
  final baseRequest = AiRequest(
    messages: const [AiMessage(role: 'user', content: 'Hello')],
  );

  group('AiMiddleware – generate interception', () {
    // Case 5.1: generate middleware forwards request unchanged by default
    test('forwards request unchanged when no mutation is applied', () async {
      final middleware = RecordingMiddleware();
      final model = FakeAiModel(providerId: 'fake', modelId: 'test');

      await middleware.interceptGenerate(
        baseRequest,
        (req) => model.generate(req),
      );

      expect(middleware.recordedRequest, same(baseRequest));
      expect(model.receivedRequests, hasLength(1));
      expect(model.receivedRequests.first, same(baseRequest));
    });

    // Case 5.2: generate middleware can modify request before forwarding
    test('downstream receives the modified request', () async {
      final middleware = RecordingMiddleware(
        requestMutation: (req) => AiRequest(
          messages: req.messages,
          providerOptions: {'injected': true},
        ),
      );
      final model = FakeAiModel(providerId: 'fake', modelId: 'test');

      await middleware.interceptGenerate(
        baseRequest,
        (req) => model.generate(req),
      );

      expect(model.receivedRequests.first.providerOptions['injected'], isTrue);
    });
  });

  group('AiMiddleware – stream interception', () {
    // Case 5.3: stream middleware forwards all events in order
    test('preserves exact event order', () async {
      final events = plainTextSequence('hello');
      final model = FakeAiModel(
        providerId: 'fake',
        modelId: 'test',
        streamEvents: events,
      );
      final middleware = RecordingMiddleware();

      final collected = await middleware
          .interceptStream(baseRequest, (req) => model.streamGenerate(req))
          .toList();

      expect(collected, hasLength(events.length));
      for (var i = 0; i < events.length; i++) {
        expect(collected[i], same(events[i]));
      }
    });

    // Case 5.4: stream middleware can observe events without mutation
    test('observed sequence equals downstream sequence', () async {
      final events = plainTextSequence('world');
      final model = FakeAiModel(
        providerId: 'fake',
        modelId: 'test',
        streamEvents: events,
      );
      final middleware = RecordingMiddleware();

      final yielded = await middleware
          .interceptStream(baseRequest, (req) => model.streamGenerate(req))
          .toList();

      expect(middleware.recordedEvents, equals(yielded));
    });

    // Case 5.5: middleware error propagation
    test('does not swallow stream errors from downstream', () async {
      final errorStream = Stream<AiStreamEvent>.error(
        StateError('downstream failure'),
      );
      final middleware = RecordingMiddleware();

      await expectLater(
        middleware
            .interceptStream(baseRequest, (_) => errorStream)
            .toList(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
