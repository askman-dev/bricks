# Channel persistence hydration plan

## Background
Users can create multiple channels in ChatScreen and send messages, but after a page refresh only the default channel is visible in the sidebar. Message history is already persisted server-side by session scope, yet channel/sub-section navigation state is not rehydrated from persisted backend data.

## Goals
- Ensure channels and sub-sections with persisted chat data are reconstructed on app load.
- Keep default channel behavior intact while merging persisted scopes.
- Minimize schema risk by reusing existing chat task/message tables.

## Implementation Plan (phased)
1. Backend scope discovery API
   - Add a service query that lists distinct `(channel_id, thread_id, session_id)` scopes for the authenticated user ordered by most recent activity.
   - Expose a new authenticated route `GET /api/chat/scopes`.
2. Mobile API client support
   - Extend `ChatHistoryApiService` with typed scope DTOs and `loadScopes`.
3. ChatScreen hydration
   - On startup, fetch scopes, reconstruct channels/sub-sections, and preserve a valid active scope.
   - Generate stable fallback display names from channel/sub IDs when explicit names are unavailable.
4. Validation
   - Add backend route/service tests and mobile API service tests.
   - Run repository bootstrap and targeted test suites.

## Acceptance Criteria
- After creating channels, sending messages, and refreshing the page, sidebar still shows previously used channels.
- Switching restored channels loads their corresponding session message history.
- `GET /api/chat/scopes` returns authenticated user scopes only, sorted by recent activity.
- Validation commands succeed: `./tools/init_dev_env.sh`, backend tests, and mobile chat API tests.
