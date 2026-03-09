import 'ai_generate_result.dart';
import 'ai_request.dart';
import 'ai_stream_event.dart';

/// Intercepts AI requests and/or stream events in a pipeline.
///
/// Middleware implementations receive the request and a [next] callback that
/// invokes the downstream handler (another middleware or the model itself).
/// They may modify the request before forwarding, observe or transform events,
/// and propagate errors.
abstract interface class AiMiddleware {
  /// Intercepts a non-streaming generate call.
  ///
  /// Call [next] with the (possibly modified) request to invoke the downstream
  /// handler. Must not swallow errors thrown by [next].
  Future<AiGenerateResult> interceptGenerate(
    AiRequest request,
    Future<AiGenerateResult> Function(AiRequest request) next,
  );

  /// Intercepts a streaming generate call.
  ///
  /// Yield events from [next] to forward them, or yield additional/modified
  /// events. Must not swallow errors emitted by the [next] stream.
  Stream<AiStreamEvent> interceptStream(
    AiRequest request,
    Stream<AiStreamEvent> Function(AiRequest request) next,
  );
}
