/// Configuration options passed to an [AiProvider] when constructing a model.
///
/// Providers accept these options at model construction time; unused fields
/// are silently ignored by providers that do not support them.
class AiProviderOptions {
  const AiProviderOptions({
    this.baseUrl,
    this.apiKey,
    this.headers = const {},
    this.extra = const {},
  });

  /// Override for the provider API base URL (e.g. for proxies or local servers).
  final String? baseUrl;

  /// API key / token used to authenticate with the provider.
  final String? apiKey;

  /// Additional HTTP headers to attach to every request.
  final Map<String, String> headers;

  /// Provider-specific extension options not covered by named fields.
  final Map<String, Object?> extra;
}
