# Background
A runtime error still occurs in deployed web builds: `Unsupported operation: Platform._environment`. This indicates `dart:io` environment access is being used on a platform where it is unsupported.

# Goals
- Remove crash behavior caused by direct `Platform.environment` access on web.
- Keep support for local/server environment variables where available.
- Preserve existing API key/base URL configuration behavior via compile-time defines and runtime environment.

# Implementation Plan (phased)
1. Refactor `RealModelGateway` default environment initialization to avoid unconditional `Platform.environment` access.
2. Add compile-time (`String.fromEnvironment`) fallbacks for supported config keys.
3. Merge runtime `Platform.environment` values only when available, catching unsupported platform exceptions.
4. Run package analysis/tests to validate no regressions.

# Acceptance Criteria
- Web runtime no longer throws `Unsupported operation: Platform._environment` when sending messages.
- API key/base URL lookup still works for both compile-time defines and runtime environment maps.
- Relevant analysis/tests pass for touched packages.
