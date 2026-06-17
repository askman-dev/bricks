# iOS Debug API Base URL

## Background

Local debug builds currently default non-web platforms to `http://localhost:3000`.
That is useful for desktop development, but it is wrong for iOS device testing:
`localhost` points at the phone, not the developer machine or production API.

For GitHub OAuth and real account history validation on iPhone, iOS debug builds
should use the same production API as release builds unless a developer
explicitly overrides `BRICKS_API_BASE_URL`.

## Goals

- Make iOS debug builds default to `https://bricks.askman.dev`.
- Preserve web debug behavior: use the current browser origin.
- Preserve local desktop/other debug behavior: use `http://localhost:3000`.
- Keep `BRICKS_API_BASE_URL` as the highest-priority explicit override.

## Implementation Plan

1. Update `LlmConfigService.resolveBaseUrl()`.
2. Add a focused test for iOS debug platform selection.
3. Reinstall the app on the connected iPhone for validation.

## Acceptance Criteria

- iOS debug builds use the production API by default.
- Existing local non-web test builds continue to use localhost.
- Developers can still override the API base URL with `BRICKS_API_BASE_URL`.

## Validation Commands

- `flutter test test/llm_config_service_test.dart`
- `flutter analyze`
- `flutter run -d <ios-device-id>`
