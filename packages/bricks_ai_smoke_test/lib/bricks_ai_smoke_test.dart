/// Smoke test package for verifying AI provider request paths.
///
/// This package provides minimal HTTP clients for testing that Anthropic and
/// Gemini API endpoints can be reached and return valid responses.
library bricks_ai_smoke_test;

export 'src/anthropic_smoke_client.dart';
export 'src/gemini_smoke_client.dart';
export 'src/provider_env_config.dart';
export 'src/provider_smoke_runner.dart';
export 'src/smoke_result.dart';
