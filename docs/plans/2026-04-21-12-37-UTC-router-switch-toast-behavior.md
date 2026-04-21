# Background
The chat composer route switcher (left-side button near the input area) currently shows a success toast whenever channel/thread router changes are saved. Product expectation is to keep the UX silent on success and only notify users when persistence fails.

# Goals
- Remove success toasts for channel router updates.
- Remove success toasts for thread router updates.
- Preserve existing failure toasts so users are informed when the update fails.

# Implementation Plan (phased)
1. Locate router save handlers in chat UI and identify success/failure toast branches.
2. Remove only the success snack bars from both channel and thread save flows.
3. Keep error handling and optimistic rollback logic unchanged.
4. Run focused Flutter checks to confirm no analyzer/test regressions.

# Acceptance Criteria
- Changing channel router does not show a success toast.
- Changing thread router does not show a success toast.
- If saving channel or thread router fails, a failure toast still appears.
- Validation command(s): `./tools/init_dev_env.sh`, then `cd apps/mobile_chat_app && flutter test` (or a focused equivalent if full suite is too slow).
