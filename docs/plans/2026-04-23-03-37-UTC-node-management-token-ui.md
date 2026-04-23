# Background
The settings area currently exposes both a Node Management entry and a separate Openclaw Token entry. The user asked to verify whether token generation outputs are equivalent and reusable, then remove duplicate token-generation entry points if redundant. The user also requested Node Management UX updates: move the add-node action to the AppBar top-right using icon + text, and switch Node Management copy to English.

# Goals
1. Verify whether token generation from Node Management and Openclaw Token page uses the same backend/service logic and whether outputs are interchangeable.
2. Remove duplicate Openclaw Token generation entry point from settings if redundant, preserving Node Management flow.
3. Move Node Management “add node” action to AppBar right side with icon + text.
4. Convert Node Management related UI copy to English.
5. Run targeted validation and summarize whether code maps require updates.

# Implementation Plan (phased)
## Phase 1: Discovery and equivalence audit
- Locate settings route definitions and both token-generation entry points.
- Trace service calls for token generation (API endpoints, payloads, and UI wiring) to confirm equivalence/reuse.
- Record findings in final summary.

## Phase 2: UI and navigation changes
- Remove/disable Settings list tile that navigates to standalone Openclaw Token page if duplicate.
- Ensure Node Management remains the canonical path to token generation.
- Update Node Management screen AppBar action to include an icon + text add-node button on the right.
- Translate Node Management-related labels/buttons/messages into English.

## Phase 3: Validation and docs alignment
- Run required bootstrap script and targeted Flutter checks/tests relevant to touched package.
- Review code map files and update if feature entry/logic index changed.
- Prepare concise change notes and verification results.

# Acceptance Criteria
- Settings no longer offers duplicate Openclaw Token generation entry if Node Management uses the same token generation logic.
- Token generation from Node Management produces output consistent with prior Openclaw token generation behavior (same data shape and intended use).
- Node Management screen shows add action in AppBar top-right with icon + text.
- Node Management visible copy is English.
- Validation commands complete successfully (or limitations are documented).
