# Background
The user asked to update the repository-level AGENTS.md guidance so that, when debugging API errors, the agent explicitly attempts to use the `vercel-api-log-context` skill to gather log context.

# Goals
1. Add a clear instruction in `AGENTS.md` for API/interface error debugging workflows.
2. Ensure the instruction references the existing `vercel-api-log-context` skill by name.
3. Keep the change minimal and easy to discover for future agent runs.

# Implementation Plan (phased)
## Phase 1: Update repository guidance
- Add a dedicated section in `AGENTS.md` for API debugging behavior.
- Insert an instruction that says to try `vercel-api-log-context` when troubleshooting API errors.

## Phase 2: Verify formatting and placement
- Confirm the new section is visible in the top-level guidance.
- Confirm wording is imperative and unambiguous.

# Acceptance Criteria
- `AGENTS.md` includes a section that explicitly instructs agents to try the `vercel-api-log-context` skill during API error debugging.
- The instruction is in the repository root `AGENTS.md` and applies to the full repo scope.
