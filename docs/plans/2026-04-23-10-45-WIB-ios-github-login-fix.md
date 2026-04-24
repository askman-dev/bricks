# iOS GitHub login fix

## Background

The Flutter web app can start GitHub OAuth through `/api/auth/github`, and the
backend callback writes the resulting JWT into browser storage before returning to
the app. The iOS build currently compiles the same login screen, but the GitHub
button uses the non-web stub implementation, which returns `null` and produces no
visible action.

## Goals

- Make the iOS GitHub button open the existing backend OAuth flow.
- Allow the backend to redirect successful native logins back to the app through a
  constrained custom URL scheme.
- Persist the returned JWT through the existing `AuthService` storage path.
- Preserve the current Flutter web OAuth behavior.

## Implementation Plan (phased)

### Phase 1: Add native OAuth launch and callback handling

- Add mobile dependencies for launching browser URLs and listening for app links.
- Add a non-web GitHub OAuth implementation that opens the backend auth URL with a
  native `return_to` target.
- Add a native OAuth callback helper that listens for `bricks://auth/github/callback`
  links, extracts `auth_token`, and returns it to the login button.
- Surface a visible login failure message instead of silently returning to idle.

### Phase 2: Configure iOS URL routing

- Register the `bricks` URL scheme in `ios/Runner/Info.plist`.
- Keep storage identity (`auth_token`) separate from the visible login button label.

### Phase 3: Update backend return target validation

- Extend `isAllowedReturnTo` to allow only the expected native callback target:
  `bricks://auth/github/callback`.
- Keep web return targets restricted to the existing HTTPS rules.
- Add backend tests for allowed/rejected native callback values.

### Phase 4: Validate

- Run `./tools/init_dev_env.sh` before Flutter checks.
- Run `cd apps/mobile_chat_app && flutter test`.
- Run `cd apps/mobile_chat_app && flutter analyze`.
- Run relevant backend tests for auth return target behavior.

## Acceptance Criteria

- Tapping "Continue with GitHub" in an iOS build opens the GitHub OAuth browser
  flow through the backend.
- A successful OAuth callback to `bricks://auth/github/callback` saves the JWT under
  the existing `auth_token` key.
- After token persistence, the app navigates to `ChatScreen`.
- Failed or cancelled login leaves the user on `LoginScreen` with a visible message.
- Web OAuth still starts from `/api/auth/github?return_to=...` and continues to use
  the existing browser redirect behavior.
- Backend return URL validation rejects arbitrary non-HTTPS schemes and only allows
  the expected native callback target.
