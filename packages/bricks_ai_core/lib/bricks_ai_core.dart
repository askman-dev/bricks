/// Core AI provider abstractions and streaming event model for the Bricks agent system.
///
/// Defines the unified interface that all AI providers must implement.
/// Business code should depend on these abstractions; provider-specific
/// packages implement them.
library bricks_ai_core;

export 'src/ai_generate_result.dart';
export 'src/ai_message.dart';
export 'src/ai_middleware.dart';
export 'src/ai_model.dart';
export 'src/ai_model_registry.dart';
export 'src/ai_provider.dart';
export 'src/ai_provider_options.dart';
export 'src/ai_request.dart';
export 'src/ai_stream_event.dart';
