# Agent Loop Timeout for Site Coding

## Background

Site coding requests often require the agent to inspect workspace config and several files before it can safely write changes. A 60 second per-step model timeout can interrupt the first coding step after successful reads but before any file writes or final answer.

## Goals

- Give site coding tasks enough time to move from read context to edits.
- Keep the existing hard bounds on steps and tool calls.
- Preserve explicit timeout failure reporting when the model still exceeds the per-step budget.

## Implementation

- Increased the default local agent-loop per-step timeout from 60 seconds to 10 minutes.
- Updated route tests and code maps to match the new default.
- Increased the max timeout clamp to 10 minutes so the new default is not clipped.

## Validation Commands

- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- --run src/routes/chat.test.ts`
- `ruby -e "require 'psych'; Psych.load_file('docs/code_maps/feature_map.yaml'); Psych.load_file('docs/code_maps/logic_map.yaml'); puts 'code maps yaml ok'"`
