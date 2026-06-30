# Media Preview and Download Actions

## Background

Chat media attachments already render authenticated thumbnails in message bubbles. Users can see generated or uploaded images, but the thumbnail itself is not interactive and there is no direct download action from the chat message.

## Goals

- Let users tap or click an image attachment to open a full-screen preview.
- Let users close the preview and return to chat with a clear icon button.
- Let users long-press an image attachment to open a context menu with a download action.
- Keep downloads authenticated by using the current bearer token instead of unauthenticated navigation.

## Implementation Plan

1. Add a small chat media download helper with a web implementation that fetches `downloadUrl` using the auth token and triggers a browser download.
2. Update message media tiles to handle tap/click and long-press gestures.
3. Add a full-screen image preview route/dialog that uses the existing media `contentUrl` and auth headers.
4. Add widget coverage for opening the preview and exposing the download menu.

## Implementation Status: 2026-06-30

- Added a web media downloader that fetches protected media with the current bearer token and saves it through a browser Blob download.
- Added tap/click handling on chat image attachments to open a full-screen authenticated preview with a close button back to chat.
- Added long-press handling on chat image attachments to show a Download context menu action.
- Added `MessageList` widget tests for opening/closing the preview and exposing the download action.

## Acceptance Criteria

- Tapping or clicking a chat image opens a full-screen preview.
- The preview has a close/cancel icon button that returns to chat.
- Long-pressing a chat image shows a context menu with Download.
- Download uses the authenticated media download URL.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && dart format lib/features/chat/widgets/message_list.dart lib/features/chat/media_download.dart lib/features/chat/media_download_stub.dart lib/features/chat/media_download_web.dart test/message_list_test.dart`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
