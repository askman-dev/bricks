# Unified Authenticated API Client

## Background

The mobile chat app currently uses several different authentication patterns for API calls. Some UI code caches an auth token and decides whether actions should run. Some API services require callers to pass `required String token` and manually build `Authorization` headers. Other services call `AuthService.getToken()` internally but still duplicate header construction.

This makes user actions fragile. A visible action can silently do nothing when the UI token cache is stale, and every service has to reimplement token lookup, authorization header formatting, missing-token handling, and unauthorized response handling.

The target architecture is a single authenticated HTTP path used by every login-required API call.

## Goals

- Move token lookup and `Authorization` header injection out of UI widgets and individual feature services.
- Make UI actions call business operations without checking token state first.
- Use one shared authenticated client for missing-token and unauthorized-response behavior.
- Keep API services focused on business parameters and response parsing.
- Preserve testability by allowing an injected underlying `http.Client`.
- Migrate incrementally, starting with the text highlight flow that exposed the current no-op failure.

## Implementation Plan

1. Define the authenticated API boundary.
   - Add an authenticated HTTP client or request executor near the auth/API infrastructure.
   - The client should fetch the current token through `AuthService.getToken()` for each authenticated request.
   - The client should inject `Authorization: Bearer <token>` and merge any caller-provided headers.
   - The client should expose request methods needed by existing services, such as `get`, `post`, `put`, `patch`, and `delete`.
   - The client should accept an optional underlying `http.Client` so tests can keep using mock clients.

2. Standardize auth error semantics.
   - Introduce a missing-token error for authenticated requests made without a token.
   - Introduce an unauthorized error for HTTP 401 responses.
   - Keep the first implementation local to API/service boundaries and avoid forcing global navigation behavior into the client.
   - Add tests proving missing token does not become a silent no-op.

3. Migrate the text highlight application flow first.
   - Convert `TextHighlightApiService` so callers no longer pass a token.
   - Route create/list/delete highlight requests through the authenticated client.
   - Keep highlight-specific request bodies, response parsing, and range logic inside the highlight service.
   - Update `ChatScreen` highlight handlers so they invoke the service directly and handle typed auth errors with visible feedback.
   - Verify the user-visible flow: select text, show the floating toolbar, click the highlight action, send a network request, and render the highlight after success.

4. Remove token gating from highlight UI actions.
   - Ensure toolbar visibility and action availability are based on selection state and callback wiring, not `_authToken != null`.
   - Treat authentication failure as an operation result, not as a reason to suppress the UI action.
   - Add a regression test for the previous failure mode where the toolbar was visible but the highlight action performed no request.

5. Migrate shared chat resource services.
   - Convert `TodoApiService` and `AssetTableApiService` to use the authenticated client.
   - Remove `required String token` from public methods that only need authentication as transport context.
   - Update call sites to pass business inputs only.
   - Add focused service tests for authorization header injection and missing-token handling through the shared client.

6. Migrate chat history operations.
   - Convert `ChatHistoryApiService` to the authenticated client.
   - Remove duplicated `Authorization` header construction from conversation, message, deletion, metadata, and usage-reporting methods.
   - Update `ChatScreen` and related call sites so chat history operations no longer depend on cached token state.
   - Keep any UI-level logged-in state only for display, routing, or initial loading decisions.

7. Migrate settings and LLM configuration APIs.
   - Convert `LlmConfigService` from direct `AuthService.getToken()` calls and manual headers to the authenticated client.
   - Preserve existing settings error messages while routing auth errors through the shared semantics.
   - Add or update tests for settings API calls so they validate behavior through the shared client.

8. Consolidate UI auth state usage.
   - Audit `ChatScreen` and other feature screens for `_authToken`, `authToken`, and token-based action gating.
   - Remove cached token reads where the value is only used to call an API.
   - Keep explicit auth checks only at application boundaries where they control routing, login state display, or session bootstrap.

9. Update tests, code maps, and documentation.
   - Add authenticated-client unit tests.
   - Update feature tests for highlight selection and highlight creation.
   - Run the relevant Flutter test suites and analyzer.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` because this change touches feature entry points, business logic, and tests.

## Acceptance Criteria

- Highlight creation no longer depends on `ChatScreen._authToken` being populated before the toolbar action is wired.
- Clicking the highlight action after selecting text sends an authenticated request when a token exists.
- Missing token produces a visible user-facing error instead of a silent no-op.
- Text highlight, todo, asset table, chat history, and LLM configuration services use the same authenticated request path after their migration phases.
- No feature service manually formats `Authorization: Bearer <token>` after it has been migrated.
- UI code no longer passes raw token strings into migrated services.
- Tests cover authenticated header injection, missing-token behavior, unauthorized-response behavior, and the highlight toolbar action path.
- Code maps are reviewed and updated for the new authenticated API path and affected feature tests.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter analyze`
- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter test test/message_list_test.dart test/highlight_selection_toolbar_web_test.dart`
- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter test -d chrome test/highlight_selection_toolbar_web_test.dart`
