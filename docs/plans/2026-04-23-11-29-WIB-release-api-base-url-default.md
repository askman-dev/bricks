# Release API base URL default

## Background

Native app GitHub login and backend-backed chat/config calls use
`LlmConfigService.resolveBaseUrl()` to choose the API server. The existing
non-web default is `http://localhost:3000`, which is useful for local debug builds
but wrong for a release iOS app with a fixed production server.

## Goals

- Make release non-web builds default to `https://bricks.askman.dev`.
- Preserve explicit `BRICKS_API_BASE_URL` overrides for all build modes.
- Preserve local `http://localhost:3000` defaults for non-release development builds.
- Keep web behavior unchanged by using `Uri.base.origin`.

## Implementation Plan (phased)

### Phase 1: Update base URL resolution

- Add a stable production API base URL constant.
- Update `resolveBaseUrl()` so precedence is:
  1. `BRICKS_API_BASE_URL` dart-define
  2. Web origin
  3. Native release production URL
  4. Native non-release localhost

### Phase 2: Add focused tests

- Add unit coverage for the default native release URL constant and current test-mode
  resolution behavior.
- Keep tests independent of real network calls.

### Phase 3: Validate

- Run `dart format` on touched Dart files.
- Run targeted Flutter tests for LLM config/base URL behavior.
- Run `flutter analyze`.
- Re-run iOS simulator build because the GitHub OAuth native implementation consumes
  this base URL.

## Acceptance Criteria

- A release iOS build without `BRICKS_API_BASE_URL` uses `https://bricks.askman.dev`.
- A build with `--dart-define=BRICKS_API_BASE_URL=...` uses the provided value.
- Debug/profile native builds can still use localhost by default.
- Existing web deployment behavior remains unchanged.
