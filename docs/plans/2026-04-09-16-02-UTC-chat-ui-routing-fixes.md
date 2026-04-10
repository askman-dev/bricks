# Background
The current React chat UI still exposes legacy `/workspace` and `/resources` paths and has multiple mobile interaction regressions in the chat screen and model settings screen. The user reported incorrect menu behavior, misplaced composer/menu layout, and incomplete section data handling.

# Goals
- Remove `/workspace` and `/resources` route entry points.
- Fix chat page interactions/layout:
  - top-left button opens a sidebar/drawer instead of the wrong menu,
  - composer config menu anchors to the lower-left composer button,
  - composer is pinned at the bottom,
  - messages render as role-specific bubbles with assistant bubbles full width,
  - top-right section menu uses fetched data and supports creating subsections.
- Add a top back header row to model settings page.

# Implementation Plan (phased)
## Phase 1: Routing and page structure
1. Update app routes to remove workspace/resources entries and ensure fallback goes to `/chat`.
2. Update tests that currently rely on `/workspace` redirect behavior.

## Phase 2: Chat page UX and data flow
1. Split chat menu state into separate states for drawer, composer menu, and section menu.
2. Implement section config fetch from backend (`/api/config?category=chat_section`) and map to menu options.
3. Implement subsection creation via POST to `/api/config` and refresh list.
4. Apply chat layout changes for bottom-pinned composer and message bubble variants.

## Phase 3: Model settings header and styling
1. Add back button header row to model settings page.
2. Extend CSS for drawer, anchored menus, bubbles, and model settings top bar.

## Phase 4: Validation and maps
1. Run web chat app tests.
2. Update code maps for changed entry/menu behavior and regression focus.

# Acceptance Criteria
- App no longer registers `/workspace` or `/resources` routes.
- Top-left chat button opens sidebar drawer; composer config button opens a separate lower-left anchored menu.
- Composer appears at the bottom of chat viewport.
- User and assistant messages render with distinct bubble styles; assistant bubble spans full message width.
- Section menu data is fetched from backend and includes working “new subsection” action.
- Model settings page has a visible top back row and title row.
- `npm test` for `apps/web_chat_app` passes.
