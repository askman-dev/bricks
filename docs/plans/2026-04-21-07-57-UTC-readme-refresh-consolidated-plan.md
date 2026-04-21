# Background
The README refresh went through multiple iterations. Review feedback requested two final adjustments: (1) use a flowchart-style ASCII diagram instead of a tree layout, and (2) consolidate previously split README planning notes into a single plan document.

# Goals
1. Keep README aligned with actual packages and current architecture language.
2. Present architecture as a flowchart-style ASCII diagram (not tree-style) above the Packages table.
3. Keep concise README/BUILD separation (README overview; BUILD.md detailed workflows).
4. Replace multiple README plan docs with one consolidated document.

# Implementation Plan (phased)
## Phase 1: README diagram refinement
- Replace the existing tree-form ASCII with a flowchart-form ASCII block.
- Ensure the flow shows channel routing, channel partitions, plugin nodes, and multi-instance controller relationship.

## Phase 2: Plan document consolidation
- Create one consolidated README plan document capturing prior goals and current feedback.
- Remove older split plan documents related to the same README refresh.

## Phase 3: Verification
- Verify diagram placement above the Packages table and readable markdown rendering.
- Verify repository now contains a single consolidated README refresh plan document.
- Confirm code maps are unchanged because this remains a documentation-only update.

# Acceptance Criteria
- README contains a flowchart-style ASCII diagram in English above the Packages table.
- Diagram expresses relationships among channels, partitions, and OpenClaw plugin nodes.
- Only one consolidated plan document remains for this README refresh task.
- No runtime behavior or code logic is changed.
