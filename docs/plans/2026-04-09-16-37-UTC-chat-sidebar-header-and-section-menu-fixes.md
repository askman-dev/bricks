# Background
The chat mobile UI has multiple parity and usability issues: sidebar header height/layout does not align with the chat top header, the message pane uses an undesired gray background, the composer can be pushed off-screen by message growth, and the top-right section menu ordering/grouping does not match the expected IA. There is also confusion around subsection default labeling, where newly created subsections appear as default.

# Goals
1. Align sidebar drawer header height and left-button/title layout with the chat page top header.
2. Remove gray background styling from the message area.
3. Keep the composer/input area fixed to the bottom of the viewport while messages scroll.
4. Update the section menu to show a grouped block containing "主区" and "新建子区", followed by the subsection list.
5. Ensure only one main section representation is shown as default in UI labels, and avoid labeling each subsection as default.

# Implementation Plan (phased)
## Phase 1: Chat layout and header alignment
- Update `apps/web_chat_app/src/styles.css` to normalize top header and drawer header heights and grid alignment.
- Adjust drawer header internals (button/title/right action spacing) so the back button and title align with the chat header controls.
- Remove the message container gray background style while preserving bubble contrast.
- Make message list area properly scrollable (`min-height: 0`) and pin composer to bottom (`position: sticky; bottom: 0`) so it remains visible.

## Phase 2: Section menu grouping and default semantics in UI
- Update `apps/web_chat_app/src/pages/ChatPage.tsx` section menu render logic:
  - Add grouped block with `主区` and `新建子区` at top.
  - Render subsection list below the group.
- Ensure `主区` is always selectable and shown explicitly.
- Remove per-subsection "Default channel" copy and only mark main section as default in labels.

## Phase 3: Validation
- Run web frontend tests for `apps/web_chat_app`.
- Run a production build to verify TypeScript and style integrity.

# Acceptance Criteria
1. Sidebar drawer header and chat top header have matching height and visually aligned left control + title layout.
2. Message list container no longer has a gray background panel.
3. Composer remains visible at the bottom while long message history scrolls independently.
4. Section dropdown first shows grouped actions (`主区`, `新建子区`) and then subsection list items.
5. UI shows only main section as default; subsection items are not labeled as default.
6. `cd apps/web_chat_app && npm test -- --run` and `cd apps/web_chat_app && npm run build` succeed.
