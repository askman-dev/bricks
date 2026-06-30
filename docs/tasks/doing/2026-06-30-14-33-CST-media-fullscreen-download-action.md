# Media Fullscreen Download Action

## Background

Desktop browser long-press and secondary-click gestures are unreliable for image attachment downloads. Chrome can open the fullscreen image preview, while Safari may not consistently trigger the thumbnail tap path.

## Goals

- Make thumbnail primary click/tap reliable in desktop browsers, including Safari.
- Add a visible download control to the fullscreen image preview.
- Keep the existing close/back-to-chat control.
- Reuse the existing authenticated media download implementation.

## Implementation Plan

1. Pass download URL, filename, and auth token into the fullscreen media preview.
2. Add a download icon button next to the close button.
3. Open image thumbnails from primary pointer down/up instead of relying only on the tap recognizer.
4. Keep long-press and secondary-click menus from also opening the preview.
5. Cover the thumbnail and fullscreen controls with a widget test.

## Acceptance Criteria

- Opening an image preview shows both `Download image` and `Back to chat` controls.
- Tapping `Back to chat` still closes the preview.
- Image thumbnails expose an `Open image` control and primary click/tap opens the preview.
- The download button uses the existing authenticated download path.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && dart format lib/features/chat/widgets/message_list.dart test/message_list_test.dart`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
