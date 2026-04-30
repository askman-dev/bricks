# Background
The current chat page may show persisted messages after refresh while the scroll position appears neither at the top nor at the bottom. The goal of this research task is to clarify the existing message-load scroll strategy before deciding when or how to change it.

# Goals
- Identify the current message loading path for the active chat scope.
- Identify the current initial and update-time scroll strategy in the message list.
- Explain why refresh can land in the middle of the scroll range.

# Implementation Plan (phased)
## Phase 1: Code-path review
1. Inspect `ChatScreen` history loading and SSE merge paths.
2. Inspect `MessageList` scroll controller, focus target, and jump-to-latest behavior.
3. Compare implementation against existing tests and historical plans.

## Phase 2: Behavior explanation
1. Summarize the effective scroll anchor and when it is applied.
2. Explain the observed middle-position result using the scroll anchor and bottom padding.
3. Note likely gaps relative to the desired latest-message behavior.

# Acceptance Criteria
- The current strategy is described with file references.
- The explanation accounts for being able to scroll both upward and downward after refresh.
- No code behavior is changed during this research pass.

# Validation Commands
- Not applicable for code behavior because this is a read-only investigation.
