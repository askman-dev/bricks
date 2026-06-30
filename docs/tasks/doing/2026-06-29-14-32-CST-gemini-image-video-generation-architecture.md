# Gemini Media Generation and Preview Architecture

## Background

Bricks currently routes local chat through `/api/chat/respond`, persists `chat_messages.content` as plain text, synchronizes message rows over `/api/chat/sync` and `/api/chat/events/:sessionId`, and sends model requests through the backend LLM abstraction backed by AI SDK `LanguageModel` adapters. The current `UnifiedMessage` contract only carries string content, and the mobile chat composer calls `onSend(String text)`.

The `chat_domain` package already defines attachment concepts, but the production mobile chat view-model, API DTOs, async transport service, database schema, and model prompt assembly do not carry attachments.

Gemini image understanding supports mixed text and image input, either as inline base64 data with a 20MB total request limit or via uploaded File API URIs for larger/reused media. Gemini image generation supports text-to-image, text-and-image-to-image editing, multi-turn image iteration, configurable image response formats, and multi-reference-image workflows. Gemini Veo video generation is a long-running operation, currently exposed separately from normal chat streaming, with generated video files retained by Google for a limited time and requiring explicit download for durable storage.

Because uploaded images, generated images, and generated videos all need preview, download, ownership, retention, and message attachment behavior, this work should be designed as a shared media capability rather than three unrelated feature patches.

## Goals

- Let users send one or more images together with text in a normal chat message.
- Let users generate images from text and edit/generate images from uploaded reference images.
- Let users generate videos from text and, where supported by the selected model, from image references.
- Preserve image attachments through mobile UI, backend validation, database persistence, sync/SSE, message rendering, and model-context replay.
- Add generated image and video capabilities through asynchronous media jobs where useful, not as fragile blocking chat requests.
- Support preview, full-size open, and download for uploaded images, generated images, and generated videos.
- Store generated media durably in Bricks-owned storage or a repository-approved asset store before provider-side temporary retention expires.
- Keep provider-specific media behavior behind backend capability interfaces so Anthropic/OpenClaw/plugin routes remain stable.
- Update code maps once implementation changes feature entry points, backend logic, database schema, tests, and documentation indexes.

## Implementation Status: 2026-06-30

The first production slice implements provider-side Gemini media generation on the Node backend:

- `POST /api/media/image-generations` calls the Gemini Interactions API, supports text-to-image and text-plus-reference-image generation, and persists the returned image as a Bricks `generated_image` media asset.
- `POST /api/media/video-generations` starts a Veo long-running operation and persists a `media_generation_jobs` row with the provider operation name.
- `GET /api/media/generation-jobs/:jobId` and `POST /api/media/generation-jobs/:jobId/poll` refresh pending video jobs; when Veo completes, Bricks downloads the provider video URI into `media/generated/videos/` and creates a `generated_video` media asset.
- Local agent tools now expose `media_image_generate` and `media_video_generate`, so Bricks Default can invoke generation through the normal tool loop.
- Video reference-image input follows the official Veo REST shape: `referenceImages` contains up to three `{ image: { inlineData: { mimeType, data } }, referenceType: "asset" }` entries. First/last frame support is also wired as `image` and `lastFrame`, with `lastFrame` requiring a first frame.
- Follow-up fix from preview testing: media generation job updates use `CURRENT_TIMESTAMP` instead of PostgreSQL-only `NOW()`, and chat-scoped agent tools receive the current `channelId`, `threadId`, and user message as prompt fallback when the model omits them.
- Follow-up fix from preview testing: successful `media_image_generate` tool results are copied into assistant `mediaAttachments`, so generated images render through the existing authenticated preview UI instead of only appearing as `[image: ...]` text markers.
- The dedicated durable worker/cron loop, generated-video completion attachment updates, poster/thumbnail renditions, and full mobile controls remain follow-up work.

Official docs checked:

- Gemini image generation / editing: https://ai.google.dev/gemini-api/docs/image-generation
- Veo video generation, reference images, first/last frames, operation polling, and download: https://ai.google.dev/gemini-api/docs/video

## Implementation Plan

1. Define a production media asset and attachment contract.
   - Add a shared media DTO for uploaded and generated assets with stable fields such as `id`, `kind`, `origin`, `mimeType`, `sizeBytes`, `filename`, `storageKey` or `url`, `thumbnailStorageKey` or `thumbnailUrl`, `providerFileUri`, `providerOperationName`, `width`, `height`, `durationMs`, `status`, and optional moderation/error metadata.
   - Use `kind` values such as `image`, `video`, and future-safe `file`; use `origin` values such as `user_upload`, `generated_image`, and `generated_video`.
   - Add a message attachment DTO that references media asset IDs and controls per-message presentation, caption text, ordering, and whether the attachment is an input reference or generated output.
   - Reconcile this with `packages/chat_domain/lib/src/attachments.dart` instead of inventing a second unrelated shape.
   - Decide whether original uploads are stored in Bricks storage first, Gemini File API first, or both. Prefer Bricks-owned storage as the canonical record, with provider file URIs treated as cache/adapter metadata.
   - Generate and persist thumbnails/posters for previews rather than forcing every chat list render to load original files.

2. Add upload, preview, and download APIs.
   - Add backend routes such as `POST /api/media/uploads` and `GET /api/media/:id` or signed-URL endpoints.
   - Add preview/download routes such as `GET /api/media/:id/preview`, `GET /api/media/:id/content`, and `GET /api/media/:id/download`, or signed URL equivalents with ownership checks.
   - Add database tables for media assets, media renditions, and message-attachment joins, or extend `chat_messages.metadata` only for a short migration bridge. Prefer normalized tables for binary lifecycle, reuse, status, cleanup, and download auditability.
   - Enforce per-user ownership, MIME allowlists, size limits, image dimension limits, and request-rate limits.
   - Return enough metadata for clients to render previews without additional heavy lookups: media ID, kind, MIME type, dimensions, duration, thumbnail URL, content URL, download URL, status, and error text.
   - For Flutter mobile/web, use `file_picker` or platform image picking to select images, preview them in the composer, upload before send, and include attachment IDs in `/api/chat/respond`.

3. Extend chat transport to carry attachments.
   - Update `ChatMessage`, `ChatHistoryApiService`, `/api/chat/respond`, `/api/chat/messages/batch`, `MessageUpsertInput`, `toMessageDto`, sync, SSE, and message rendering to include attachments.
   - Allow text to be empty only when attachments are present if product wants image-only sends.
   - Make user bubble rendering show image thumbnails with retry/remove states before send and durable preview states after sync.
   - Make assistant bubble rendering show generated image and video outputs as first-class attachments, with preview, open, and download actions.
   - Ensure plugin/OpenClaw dispatch receives attachment metadata without assuming local filesystem paths are available.

4. Extend LLM request types from text-only to multi-part messages.
   - Change `UnifiedMessage.content` from `string` to a typed text/image/file part list, while preserving a simple helper for existing text-only callers.
   - In `listSessionMessagesForModel`, reconstruct recent messages with attachments and budget text plus media references deliberately.
   - For Google AI Studio, map image attachments to AI SDK/Gemini multimodal parts or to direct `@google/genai` Interactions API inputs. Use inline data only for small images; use Gemini Files API for larger or repeated images.
   - For Anthropic and any unsupported route, either map to that provider's media format or return a clear capability error.

5. Add provider capability detection.
   - Extend model/provider config metadata with capabilities such as `textInput`, `imageInput`, `imageGeneration`, `imageEditing`, `videoGeneration`, `referenceImages`, `fileUpload`, `streamingText`, and `backgroundJobs`.
   - Surface unsupported combinations in UI before send, for example when the active route cannot accept images, cannot generate images, or cannot generate video.
   - Keep display labels and stable capability IDs separate so model names can change without rewriting feature logic.
   - Add smoke tests for Gemini text+image, image generation, and negative tests for unsupported providers/routes.

6. Implement image generation and editing.
   - Add `POST /api/media/image-generations` or a chat command/tool path that accepts a prompt, optional reference media IDs, response format options, and an idempotency key.
   - Use Gemini image models for text-to-image and text-and-image-to-image flows, decoding provider output images and saving them as Bricks media assets immediately.
   - Treat multi-turn image editing as a media job/session concern: store provider interaction IDs only as provider metadata, while keeping the generated media asset as the durable product record.
   - Attach generated images to assistant messages and update the chat over existing sync/SSE.
   - Support image preview, full-size open, and download from the same media APIs used for uploads.
   - Represent safety blocks, provider errors, empty image responses, and unsupported format requests as explicit failed assistant/job states.

7. Implement video generation as a durable async job.
   - Add a media job table with `job_id`, `job_type`, `user_id`, `channel_id`, `session_id`, `thread_id`, `prompt`, input attachment IDs, provider, model, provider operation name, status, progress/status text, result media IDs, error, timestamps, and idempotency key.
   - Add `POST /api/media/video-generations` or a chat command/tool path that creates a job and writes a chat status message.
   - Support text-to-video first, then image-to-video/reference-image generation when the selected Veo model supports it.
   - Poll Veo long-running operations from a durable worker/cron/retry loop, not from a post-response in-process async function.
   - Download finished videos immediately into Bricks-owned storage, create poster/thumbnail renditions, attach the result to an assistant message, and update status over the existing SSE/sync mechanism.
   - Support video preview/playback, open, and download from the same media APIs used for generated images.
   - Represent failure states explicitly in chat so safety blocks, provider errors, timeouts, and expired provider files do not leave a permanent spinner.

8. Design unified media UI entry points.
   - Add an image attach icon to the composer and thumbnail strip above the text field.
   - Add generation actions for `Generate image` and `Generate video`, either through a composer mode selector, slash commands, or agent tools. Keep these modes explicit until media generation behavior is stable.
   - Provide per-attachment actions for preview/open, download, remove-before-send, retry-upload, retry-generation, and copy media link where appropriate.
   - Render uploaded images, generated images, and generated videos consistently in the message list, while preserving compact chat readability.
   - Use icon buttons and tooltips for attachment, preview, download, remove, and retry actions.
   - Ensure mobile and desktop layouts have bounded preview sizes, no text overlap, and no layout shift while thumbnails load.

9. Validate and document.
   - Add backend unit tests for attachment validation, ownership, preview/download authorization, sync serialization, model part conversion, generated image persistence, and Veo job state transitions.
   - Add Flutter widget tests for composer image attachment, media preview/download actions, generated media rendering, and unsupported-provider UI states.
   - Add provider smoke coverage in `packages/bricks_ai_smoke_test` for Gemini image input and Gemini image generation, plus a gated Veo smoke test if cost/availability allows.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` after implementation.

## Acceptance Criteria

- A user can attach an image, type text, send both together, refresh the conversation, and still see the image and text in the same message.
- A Gemini-capable local route receives the image and text as multimodal input and can answer questions about the image.
- A user can generate an image from text and see the result as a durable assistant attachment with preview and download actions.
- A user can generate or edit an image using uploaded reference images when the selected model supports image editing/reference images.
- Unsupported providers/routes show a clear error before or during send, without losing the draft or creating a stuck assistant message.
- A user can request video generation, see an accepted/pending state, leave and return to the thread, and later see either a playable generated video or a clear failure message.
- Uploaded images, generated images, and generated videos support preview/open and download with ownership checks.
- Generated videos and generated images are downloaded or decoded into Bricks-owned storage before any provider-side retention window expires.
- Video generation does not depend on Vercel post-response in-process work continuing after the HTTP response has been sent.
- Existing text-only chat, OpenClaw plugin routing, message sync, and thread naming continue to work.
- Code maps are updated to include the new media upload, preview/download, multimodal model routing, image generation, and video generation job paths.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter test`
- `cd packages/bricks_ai_smoke_test && dart test`
