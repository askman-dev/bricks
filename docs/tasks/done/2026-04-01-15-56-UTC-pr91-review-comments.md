# Background
PR #91 received review comments around async error handling, type safety, stream cancellation ordering, and model list normalization.

# Goals
- Resolve all inline review comments with robust, typed implementations.
- Prevent spinner/deadlock behavior when loading configs fails.
- Normalize and validate model preference parsing to avoid malformed entries.

# Implementation Plan (phased)
1. Refactor `_loadAgents` to avoid untyped `Future.wait` casts.
2. Add `try/catch` around startup loading and ensure loading flags are cleared on all paths.
3. Await stream subscription cancellation during session reset.
4. Trim/default/normalize/dedupe model values while protecting against empty entries.
5. Run analysis and mobile app tests.

# Acceptance Criteria
- Review comments on the referenced lines are addressed in code.
- Startup gracefully handles config fetch failures without indefinite loading state.
- Model list parsing does not emit empty/duplicate malformed entries.
