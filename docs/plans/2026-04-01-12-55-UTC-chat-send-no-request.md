# Background
User reports that typing and sending a chat message in the web UI does not produce any corresponding network request in DevTools and no assistant reply is received.

# Goals
- Reproduce or identify the code path that handles chat send actions.
- Determine why no outbound request is being issued.
- Implement a fix so sending a message reliably triggers the backend request.
- Validate behavior with repository checks.

# Implementation Plan (phased)
1. Inspect chat UI send handler wiring and state guards in Flutter widgets/view-models.
2. Trace the request pipeline from send action to API client invocation.
3. Fix any gating, early-return, or misconfigured endpoint/client logic preventing request dispatch.
4. Run targeted static analysis/tests for the affected modules and summarize results.

# Acceptance Criteria
- Sending a message from the chat input invokes the request pipeline (observable in code flow and testable behavior).
- No unconditional/incorrect early-return prevents network dispatch when valid input is provided.
- Existing relevant checks pass (for example `flutter analyze` and/or targeted tests) for touched modules.
