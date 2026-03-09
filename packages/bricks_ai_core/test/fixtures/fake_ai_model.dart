import 'package:bricks_ai_core/bricks_ai_core.dart';

/// A controllable [AiModel] for contract and middleware tests.
///
/// - Configurable [generate] result.
/// - Configurable [streamGenerate] event sequence.
/// - Records every [AiRequest] it receives.
class FakeAiModel implements AiModel {
  FakeAiModel({
    required this.providerId,
    required this.modelId,
    this.options,
    AiGenerateResult? generateResult,
    List<AiStreamEvent>? streamEvents,
    AiModelCapabilities? capabilities,
  })  : _generateResult = generateResult ??
            const AiGenerateResult(
              output: [AiTextBlock('fake response')],
              finishReason: AiFinishReason.stop,
            ),
        _streamEvents = streamEvents ?? const [],
        _capabilities = capabilities ?? const AiModelCapabilities();

  @override
  final String providerId;

  @override
  final String modelId;

  /// The options passed when this model was constructed, if any.
  final AiProviderOptions? options;

  final AiGenerateResult _generateResult;
  final List<AiStreamEvent> _streamEvents;
  final AiModelCapabilities _capabilities;

  /// All requests received by [generate] or [streamGenerate], in order.
  final List<AiRequest> receivedRequests = [];

  @override
  AiModelCapabilities get capabilities => _capabilities;

  @override
  Future<AiGenerateResult> generate(AiRequest request) async {
    receivedRequests.add(request);
    return _generateResult;
  }

  @override
  Stream<AiStreamEvent> streamGenerate(AiRequest request) {
    receivedRequests.add(request);
    return Stream.fromIterable(_streamEvents);
  }
}
