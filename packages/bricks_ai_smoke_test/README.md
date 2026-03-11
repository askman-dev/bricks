# bricks_ai_smoke_test

Smoke test package for verifying AI provider request paths in the Bricks project.

## Purpose

This package provides minimal HTTP clients for testing that Anthropic and Gemini API endpoints can be reached and return valid responses. It is designed for **request-path verification only**, not as a full provider abstraction layer.

## Features

- Environment-based configuration for Anthropic and Gemini providers
- Minimal HTTP clients for each provider
- Clear error messages and success/failure reporting
- Safe API key handling (no logging of secrets)
- Comprehensive unit and integration tests

## Usage

### Configuration

The package reads configuration from environment variables:

#### Anthropic
- `TEST_ANTHROPIC_API_KEY` (required)
- `TEST_ANTHROPIC_BASE_URL` (optional, defaults to `https://api.anthropic.com`)
- `TEST_ANTHROPIC_MODEL` (optional, defaults to `claude-3-haiku-20240307`)

#### Gemini
- `TEST_GEMINI_API_KEY` (required)
- `TEST_GEMINI_BASE_URL` (optional, defaults to `https://generativelanguage.googleapis.com`)
- `TEST_GEMINI_MODEL` (optional, defaults to `gemini-1.5-flash`)

### Running Smoke Tests

```dart
import 'package:bricks_ai_smoke_test/bricks_ai_smoke_test.dart';

void main() async {
  final runner = ProviderSmokeRunner();

  // Run all smoke tests
  final results = await runner.runAllTests();

  for (final entry in results.entries) {
    final provider = entry.key;
    final result = entry.value;

    if (result.success) {
      print('✓ $provider: ${result.outputText}');
    } else {
      print('✗ $provider: ${result.errorMessage}');
    }
  }
}
```

### Running Tests

Unit tests (no API calls required):
```bash
cd packages/bricks_ai_smoke_test
dart test --exclude-tags=integration
```

Integration tests (requires real API keys):
```bash
export TEST_ANTHROPIC_API_KEY="your-key"
export TEST_GEMINI_API_KEY="your-key"
cd packages/bricks_ai_smoke_test
dart test --tags=integration
```

## CI Integration

The package includes a GitHub Actions workflow (`.github/workflows/ai_provider_smoke_test.yml`) that runs tests automatically on pull requests and can be triggered manually.

Required GitHub Secrets:
- `TEST_ANTHROPIC_API_KEY`
- `TEST_GEMINI_API_KEY`

Optional GitHub Variables:
- `TEST_ANTHROPIC_BASE_URL`
- `TEST_GEMINI_BASE_URL`

## Security

- API keys are never logged or printed
- Request/response bodies are not logged in production
- All sensitive data is sanitized before any output

## Architecture

```
lib/
├── bricks_ai_smoke_test.dart         # Public API
└── src/
    ├── provider_env_config.dart       # Config readers
    ├── anthropic_smoke_client.dart    # Anthropic HTTP client
    ├── gemini_smoke_client.dart       # Gemini HTTP client
    ├── smoke_result.dart              # Result types
    └── provider_smoke_runner.dart     # Test orchestrator
```

## Future Work

This package is intentionally minimal. Future enhancements will include:

1. Full `bricks_ai_core` provider abstractions
2. Provider adapters conforming to unified interfaces
3. Streaming support
4. Tool calling support
5. Retry policies and middleware

See [Issue #11](https://github.com/askman-dev/bricks/issues/11) for the original implementation plan.
