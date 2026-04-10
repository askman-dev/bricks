# React Frontend Rebuild and Flutter Removal Plan

## Background
The current user-facing client is implemented in Flutter (`apps/mobile_chat_app`) and relies on Dart packages in `packages/`. The request is to fully migrate frontend functionality (login, chat, sidebar navigation) to a React-based implementation and remove Flutter code from this repository.

## Goals
1. Introduce a React web frontend that supports:
   - GitHub OAuth login trigger and authenticated session check.
   - Chat conversation view with message list and send action.
   - Sidebar navigation for chat/workspace/projects/skills/resources sections.
2. Remove Flutter/Dart application code from the repository.
3. Update build/deploy and project docs to reflect the React stack.
4. Update code maps so feature-to-code navigation remains accurate.

## Implementation Plan (phased)
1. **Scaffold React app**
   - Create `apps/web_chat_app` with TypeScript + Vite configuration.
   - Add React routing/layout primitives and shared API client.
2. **Port core user flows**
   - Implement login screen and OAuth redirect trigger.
   - Implement chat screen with local session state and `/api/chat/respond` integration.
   - Implement sidebar with routes for chat/workspace/projects/skills/resources.
3. **Repository migration cleanup**
   - Remove Flutter app and Dart package directories.
   - Replace Flutter-oriented build scripts/config with React equivalents.
   - Update docs (`README.md`, `BUILD.md`) for React workflow.
4. **Code map maintenance and validation**
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` with React entry paths and tests.
   - Validate YAML syntax and run frontend/backend checks.

## Acceptance Criteria
1. Running `npm --prefix apps/web_chat_app run build` succeeds and produces deployable static assets.
2. Running `npm --prefix apps/web_chat_app run test` succeeds for React feature flow tests.
3. Login, chat send, and sidebar route switching are covered by automated tests and mapped in code maps.
4. Flutter app source (`apps/mobile_chat_app`) and Dart package source are removed from the repository.
5. Deployment config points to the React build output instead of Flutter web output.
