# Media Upload Preview and Gemini Image Input

## Background

Production chat can log in, send text, and receive assistant replies. Image upload now reaches the backend and persists as channel media, but the draft composer shows only a generic icon after upload, the draft preview request misses the auth token, and Gemini responses do not yet use uploaded image content as multimodal input.

## Goals

- Show selected image attachments in the composer as real thumbnails with clear uploading, remove, and retry states.
- Ensure authenticated media preview requests work before send and after send.
- Send uploaded images to Gemini-capable chat requests as multimodal image parts so the model can answer based on the image.
- Preserve existing text-only chat and unsupported-provider behavior.

## Implementation Plan

1. Update the mobile composer pending attachment UI to render authenticated image previews instead of a static icon.
2. Add a temporary uploading tile with spinner and retry affordance when upload fails.
3. Extend backend model message assembly to include media attachment metadata for recent user messages.
4. Convert image media assets into AI SDK multimodal parts for Google AI Studio requests, while keeping Anthropic/text-only requests stable.
5. Add focused tests for authenticated preview UI state and multimodal request construction.

## Acceptance Criteria

- A selected image shows a small preview tile while attached to the draft.
- During upload, the composer shows a bounded square tile with progress indication and a close action.
- If upload fails, the tile offers retry/removal instead of silently disappearing.
- Draft and sent-message previews include the current auth token.
- A Gemini-capable route receives uploaded image bytes as image parts and can answer questions about image content.
- Text-only chat continues to work.

## Verified Status

- Production `craft.bricks.cool` login, text send, and assistant text reply were already verified before this fix.
- Preview subdomain access was restored after Cloudflare edge certificate coverage was updated for `*.craft-dev.bricks.cool`.
- Preview login, text/image send, uploaded image preview inside the sent message, and image persistence after refresh were manually verified.
- Draft upload now shows a small thumbnail/progress tile during upload, and successful uploaded draft media uses an authenticated preview request.
- Gemini image understanding was manually verified: the assistant answered based on the actual uploaded image content.
- Upload failure retry UI is implemented but the offline/network-failure retry path has not yet been manually smoke tested.
- Media download remains covered by the existing authenticated download endpoint, but it was not part of this manual first-batch browser pass.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter analyze`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart test/chat_history_api_service_test.dart`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null`
