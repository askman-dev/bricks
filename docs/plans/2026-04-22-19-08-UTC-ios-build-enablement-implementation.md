# iOS build enablement implementation

## Problem

`apps/mobile_chat_app` needs a first-class iOS host project. A Flutter app's
Dart code is not sufficient by itself for iOS builds; the Flutter tool also
needs an Xcode project, a Runner target, CocoaPods integration, build
configuration files, and app metadata. If the `ios/` directory is missing,
`flutter build ios` fails structurally before normal compilation even begins.

## Implementation principles

- Restore a standard Flutter iOS host project for the app package instead of
  inventing a custom layout.
- Keep machine-specific signing data out of committed project files.
- Put shared defaults in versioned xcconfig files and allow local overrides for
  device signing.
- Validate simulator, device, and launch-mode behavior separately because they
  exercise different parts of the iOS toolchain.

## Technical approach

### 1. Restore the iOS host project

Create the missing `apps/mobile_chat_app/ios/` project using the standard
Flutter iOS structure for the current app package. The restored project needs
the usual Flutter iOS pieces:

- `ios/Podfile`
- `ios/Runner.xcodeproj`
- `ios/Runner.xcworkspace`
- `ios/Runner/Info.plist`
- `ios/Runner/AppDelegate.swift`
- app assets, storyboards, and the test target scaffold

This step solves the root structural problem: without the host project, Flutter
cannot invoke Xcode for iOS at all.

### 2. Define app identity in shared project files

Set the visible app name and bundle-related settings in the committed iOS
project so every contributor builds the same app identity by default. In this
project that means:

- the display name should be `Bricks`
- the iOS bundle identifier should resolve from shared build settings

`Info.plist` should keep using build variables such as
`$(PRODUCT_BUNDLE_IDENTIFIER)` rather than embedding local machine values.

### 3. Use xcconfig indirection for signing and bundle settings

The committed Xcode project should not hardcode a contributor's Apple team or
local signing state. Instead:

- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`

should define shared keys such as:

- `APP_BUNDLE_IDENTIFIER`
- `APP_DEVELOPMENT_TEAM`

and optionally include a local override file:

- `#include? "Local.xcconfig"`

Then `ios/Runner.xcodeproj/project.pbxproj` should read:

- `PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_IDENTIFIER)"`
- `DEVELOPMENT_TEAM = "$(APP_DEVELOPMENT_TEAM)"`

This keeps the committed project portable while still allowing local real-device
signing.

### 4. Keep local signing config out of version control

If a developer needs real-device deployment, they can create
`ios/Flutter/Local.xcconfig` on their machine with their own team identifier and
any local bundle override. That file is local operational state, not shared
source code, so it should not be committed.

This split is the cleanest implementation pattern:

- committed files describe how the project is built
- local override files describe who is signing it on one machine

### 5. Let Flutter regenerate ephemeral iOS build files

Generated Flutter iOS files such as these should remain uncommitted:

- `ios/Flutter/Generated.xcconfig`
- `ios/Flutter/flutter_export_environment.sh`
- `ios/Flutter/ephemeral/`
- `ios/Pods/`
- `ios/.symlinks/`

They are derived from `flutter pub get`, CocoaPods resolution, and local build
state. The repository should keep only the stable project definition, not the
generated outputs.

### 6. Validate the build in layers

Use staged validation rather than jumping directly to device install:

1. Bootstrap the workspace:
   - `./tools/init_dev_env.sh --no-doctor`
2. Verify the iOS project structure with a simulator build:
   - `cd apps/mobile_chat_app && flutter build ios --simulator --debug`
3. Verify device compilation without requiring final signing:
   - `cd apps/mobile_chat_app && flutter build ios --debug --no-codesign`
4. Verify the app logic still passes tests:
   - `cd apps/mobile_chat_app && flutter test`
5. Verify native launch behavior with a release build:
   - `cd apps/mobile_chat_app && flutter clean && flutter pub get && flutter build ios --release`

This order isolates structural issues, Pod integration issues, signing issues,
and runtime launch issues more cleanly.

## Launch-mode note

On iOS, a Flutter `debug` build is not equivalent to a normal distributable app
build. A debug build expects Flutter tooling or Xcode to be attached. That
means:

- `debug` is appropriate for `flutter run` / Xcode debugging
- `release` or `profile` is required for normal home-screen/native launch

So if an app installs successfully but crashes when launched directly from the
phone, launch mode must be checked before assuming there is an application logic
bug.

## Commit boundary

Commit:

- `apps/mobile_chat_app/.metadata`
- shared files under `apps/mobile_chat_app/ios/`

Do not commit:

- `apps/mobile_chat_app/ios/Flutter/Local.xcconfig`
- `apps/mobile_chat_app/ios/Pods/`
- `apps/mobile_chat_app/ios/.symlinks/`
- `apps/mobile_chat_app/ios/Flutter/Generated.xcconfig`
- `apps/mobile_chat_app/ios/Flutter/flutter_export_environment.sh`
- other generated or machine-specific files

## Result

The correct implementation is not "copy another app." The correct implementation
is to restore the standard Flutter iOS host project, parameterize signing
through xcconfig indirection, keep local credentials out of Git, and validate
simulator, device, and release launch paths independently.
