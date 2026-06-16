# Mobile Agents Directory Setup Fix

## Background

After GitHub login on the locally installed iOS app, chat setup fails with:

`Unsupported operation: agentsDirectory is not supported on this platform.`

Chat setup creates the local agents repository before loading persisted scopes
and messages. Because `PlatformPathsImpl.agentsDirectory()` only supported
desktop platforms, iOS threw before history hydration could run, making the app
look like the signed-in account had no history.

## Goals

- Support mobile sandbox paths for the local agents directory.
- Avoid blocking chat history hydration on iOS/Android.
- Keep desktop and web path behavior unchanged.

## Implementation Plan

1. Extend `PlatformPathsImpl` to return iOS sandbox paths under
   `Library/Application Support` and `Library/Caches`.
2. Extend Android paths under the app sandbox inferred from `Directory.systemTemp`.
3. Update `PlatformPaths` documentation.
4. Validate with Dart/Flutter analysis and reinstall the iOS app locally.

## Acceptance Criteria

- iOS no longer throws `agentsDirectory is not supported on this platform`
  during chat setup.
- GitHub-authenticated mobile users can proceed to scope/message hydration after
  login.
- Existing desktop path behavior is preserved.

## Validation Commands

- `dart format packages/platform_bridge/lib/src/io/platform_paths_io.dart packages/platform_bridge/lib/src/platform_paths.dart`
- `flutter analyze`
- `flutter run --release -d <ios-device-id>`
