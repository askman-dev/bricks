# Background
Refactor branch navigation drawer on mobile differs from main branch behavior/UI: it shows a simple three-item list with a close button, while main branch includes current chat context, agents section, and channels section.

# Goals
- Compare current refactor implementation against main branch intended behavior.
- Restore layout, functionality, and logic parity with main-branch navigation (agents + channels structure).
- Validate with targeted checks.

# Implementation Plan (phased)
1. Identify navigation drawer component(s) and related state/actions in current branch.
2. Compare with main-branch expected structure (agents/channels/current-chat) and locate regressions from refactor.
3. Implement fixes to align component layout and behaviors with main branch.
4. Run relevant lint/tests and sanity checks for touched package(s).
5. Update code map files if entry/logic/test/doc index changed; otherwise document why no update is needed.

# Acceptance Criteria
- Mobile navigation drawer renders current chat, agents section, and channels section rather than a flat three-item menu.
- Interaction handlers for agent/channel actions work consistently with main branch.
- No regressions introduced in touched module checks.
- If code maps are unchanged, final report explains why no code map update is required.
