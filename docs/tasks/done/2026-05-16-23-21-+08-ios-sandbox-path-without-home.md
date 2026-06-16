# iOS Sandbox Path Without HOME

## Background

The iOS debug app can show `Failed to load chat setup: Unsupported operation: HOME environment variable is not available on this platform.` during startup. The mobile platform path implementation added iOS support but still used `Platform.environment['HOME']`, which is not reliable in the iOS app sandbox.

## Goals

- Resolve iOS document, cache, and agents directories without reading `HOME`.
- Keep desktop behavior unchanged.
- Preserve Android mobile path behavior.
- Add a small unit test for the mobile temp-directory-to-app-container path logic.
- Keep chat history loading independent from local custom-agent file availability.

## Implementation Plan

1. Add a mobile app data directory resolver based on `Directory.systemTemp.path`.
2. Use that resolver for iOS `Documents`, `Library/Caches/bricks`, and `Library/Application Support/bricks/agents`.
3. Keep Android on the same temp-parent resolver it already effectively used.
4. Make startup custom-agent loading best-effort so local file path failures fall back to built-in agents and do not block remote chat setup.
5. Validate the resolver with platform-independent unit tests.

## Acceptance Criteria

- iOS path resolution does not call `_requiredEnv('HOME')`.
- `agentsDirectory()` on iOS resolves under the app sandbox `Library/Application Support/bricks/agents`.
- Startup chat setup no longer fails because `HOME` is missing.
- Startup chat setup continues loading scopes, channel names, and active history even if local custom-agent files cannot be read.
- Existing mobile chat API base URL behavior remains unchanged.

## Validation Commands

- `cd packages/platform_bridge && dart test`
- `cd apps/mobile_chat_app && flutter test test/llm_config_service_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
