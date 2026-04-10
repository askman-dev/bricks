# Background
The mobile web chat UI currently has multiple regressions: the composer is not pinned to the bottom on iOS, the message region shows an unnecessary horizontal scrollbar, an unintended red "ask" label appears above messages, and there is no visible loading animation while waiting for assistant replies.

# Goals
1. Pin the message input/composer area to the bottom viewport/safe area.
2. Remove horizontal overflow/scrollbar from the message region.
3. Remove the unintended red "ask" marker from the chat body.
4. Show a clear in-thread loading animation while waiting for AI response.

# Implementation Plan (phased)
## Phase 1: Locate and patch chat layout/rendering
- Inspect chat container, message list, and composer layout styles/components.
- Update CSS/layout constraints to prevent horizontal overflow and ensure bottom anchoring with safe-area support.
- Remove the source for the stray "ask" label in message rendering.

## Phase 2: Add waiting-state animation
- Identify assistant pending state in message pipeline.
- Render a visible typing/loading indicator bubble during pending assistant response.
- Ensure the indicator is removed when response content arrives.

## Phase 3: Validate and document
- Run targeted checks (lint/type-check/tests or package-specific checks as available).
- Update code maps if feature/logic index changed.

# Acceptance Criteria
- On mobile viewport, the composer visually sits against the bottom safe area and remains reachable while scrolling.
- No horizontal scrollbar appears in message list under normal chat content.
- The unintended red "ask" label is absent from chat message area.
- After a user sends a message and before assistant reply arrives, a loading animation is visible in the conversation.
- Validation command(s) complete successfully: at minimum run project-appropriate checks for the touched app (e.g., `npm run lint`, `npm run type-check`, or relevant package test command).
