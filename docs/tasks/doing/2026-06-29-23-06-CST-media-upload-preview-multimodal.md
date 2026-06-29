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

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter test`
