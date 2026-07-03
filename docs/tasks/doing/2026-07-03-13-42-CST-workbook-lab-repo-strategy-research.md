# Workbook Lab Repo Strategy Research

## Background

Workbook Lab is a proposed new iOS-first product surface for generating printable workbook-style images from short user prompts. The first product slice is not a full Bricks chat clone. It needs a focused creation flow, prompt wrapping, gallery/template discovery, and user-created variants that can be shared or remixed.

The current Bricks repository already has several reusable backend primitives:

- Authenticated API access through the Node backend and mobile `AuthenticatedApiClient`.
- Channel-scoped file storage under user sandbox roots.
- Media upload, preview, content, and download routes.
- Gemini-backed image generation that stores generated images as durable Bricks media assets.
- Chat scope instructions and composed system prompts that can inspire a Workbook Lab prompt wrapper.
- Chat thread fork records that can inspire, but should not directly become, template instance remixing.

The missing product domain is Workbook Lab itself: templates, gallery/showcase pages, generated workbook instances, sharing, remix/fork lineage, and product-specific moderation/print constraints.

### Option 1: New Repository With Copied Code

This creates a separate Workbook Lab repository and copies selected code from Bricks.

Good fit when the app must quickly become an independent product with separate release cadence, branding, App Store identity, and a smaller codebase. The new repo could copy the mobile auth client, selected DTOs, media API wrappers, and design patterns while still calling the existing Bricks backend.

Main risk: copied code becomes stale quickly. Auth, media DTOs, generated image job semantics, preview authorization, and backend response contracts would need duplicate maintenance. If the backend keeps changing in Bricks, the new repo needs a deliberate SDK or generated client soon.

### Option 2: New App Folder Inside This Monorepo

This adds a new app such as `apps/workbook_lab_app` inside the existing Bricks monorepo, while reusing the same Node backend and shared packages.

Good fit for the current stage because the frontend can be entirely new while still depending on shared packages, the existing backend, and the same local/dev/test workflow. The repo already treats `apps/**` and `packages/**` as first-class workspace members, so this is aligned with the current structure rather than a special exception.

Main risk: the new product can be visually and conceptually dragged toward the existing chat console unless the app has a strict boundary. The Workbook Lab app should own its navigation, visual system surface, and product routes instead of embedding the old chat UI.

## Goals

- Support one-sentence text-to-image generation for workbook pages.
- Support prompt wrapping so app-level constraints can force A4 paper, cartoon, girl-friendly worksheet style, and future configurable style keywords.
- Add template/showcase/gallery concepts for math puzzles, English practice, story pages, and similar categories.
- Add generated user instances that can be shared and remixed from templates or other shared instances.
- Reuse Bricks backend capabilities without forcing Workbook Lab to inherit the existing chat-console frontend.
- Keep display labels, style keywords, and stable storage identities separate.

## Implementation Plan

1. Start Workbook Lab inside this monorepo.
   - Create a new app folder under `apps/`, not inside `apps/mobile_chat_app`.
   - Reuse shared packages only where they naturally fit, especially authenticated API access, media DTOs, and design tokens.
   - Keep the first screen as the actual workbook creation/gallery experience, not a chat shell.

2. Introduce Workbook Lab backend domain objects in the existing Node backend.
   - Add templates with stable IDs, display names, category tags, style presets, prompt wrapper text, and example media references.
   - Add workbook instances that store owner, source template, source instance when remixed, prompt input, resolved prompt, generated media ID, visibility, and share metadata.
   - Add remix lineage separately from chat thread forks. Chat forks are useful precedent for context inheritance, but Workbook Lab needs product objects users can browse and share.

3. Build prompt wrapping as a first-class service.
   - Treat the user sentence as the user intent.
   - Compose it with app-level constraints such as A4 page, printable worksheet, cartoon illustration, target style keywords, age range, and safety rules.
   - Store both the user sentence and the resolved provider prompt for reproducibility and moderation review.

4. Reuse existing media generation for the first slice.
   - Call the existing image generation service or expose a Workbook-specific route that delegates to it.
   - Store the generated image as a `generated_image` media asset.
   - Return the media preview/content/download URLs to the new app.
   - Avoid video and long-running media work in the first slice unless product scope changes.

5. Add the new frontend as a focused iOS app.
   - Implement template browsing, prompt entry, generation result preview, save/share, and remix entry points.
   - Keep the UI independent from the existing chat screen.
   - Use the existing auth token path initially if account continuity matters.

6. Split to a new repository later only after the product contract stabilizes.
   - Extract or publish a small API client/SDK instead of copying live app internals.
   - Move the frontend when backend contracts, template schema, and media response DTOs are stable enough to version.

## Acceptance Criteria

- A user can open Workbook Lab, choose or start from a template category, type one sentence, and generate a workbook-style image.
- The generated image respects a configurable prompt wrapper rather than relying only on the raw user sentence.
- A generated image is stored durably and can be previewed, opened, and downloaded through authenticated media routes.
- A user-created instance records its source template or source instance so shared examples can be remixed.
- Gallery/showcase pages can distinguish official templates from user-shared instances.
- The new frontend is visibly and structurally independent from the existing Bricks chat console.
- Existing Bricks chat/media flows continue to work.
- Code maps are updated when actual app routes, backend routes, database migrations, or shared package surfaces are implemented.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/workbook_lab_app && flutter test`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null`
