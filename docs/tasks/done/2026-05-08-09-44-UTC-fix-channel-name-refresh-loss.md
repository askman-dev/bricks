# Background
Users reported that when creating a channel and entering a custom channel name, refreshing the page causes that channel name to be lost.

# Goals
- Persist the channel display name at channel creation time so a page refresh restores the custom name.
- Keep behavior consistent with channel rename persistence.

# Implementation Plan (phased)
1. Inspect channel creation flow in `chat_screen.dart` and confirm whether `saveChannelName` is called when creating channels.
2. Update channel creation logic to persist the newly entered name through `ChatHistoryApiService.saveChannelName` when an auth token is available.
3. Run focused static checks/tests relevant to the modified file.

# Acceptance Criteria
- Creating a channel with a custom name triggers persistence of that name via the chat history API when authenticated.
- After refresh/reload, the channel retains the user-provided name rather than reverting.

# Validation Commands
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
