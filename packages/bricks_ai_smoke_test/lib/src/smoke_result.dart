/// Result of a provider smoke test.
///
/// Contains success status, output text, and optional error information.
class ProviderSmokeResult {
  /// The provider name (e.g., 'anthropic', 'gemini').
  final String provider;

  /// Whether the request succeeded.
  final bool success;

  /// HTTP status code if available.
  final int? statusCode;

  /// The output text returned by the provider.
  final String? outputText;

  /// Error message if the request failed.
  final String? errorMessage;

  const ProviderSmokeResult({
    required this.provider,
    required this.success,
    this.statusCode,
    this.outputText,
    this.errorMessage,
  });

  @override
  String toString() {
    if (success) {
      return 'ProviderSmokeResult($provider: success, '
          'statusCode: $statusCode, '
          'outputText: ${outputText?.substring(0, outputText!.length > 50 ? 50 : outputText!.length)}...)';
    } else {
      return 'ProviderSmokeResult($provider: failed, '
          'statusCode: $statusCode, '
          'error: $errorMessage)';
    }
  }
}
