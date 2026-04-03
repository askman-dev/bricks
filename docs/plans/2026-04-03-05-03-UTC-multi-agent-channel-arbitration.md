# Multi-Agent Channel Arbitration Plan

## Background
We are designing a backend multi-agent framework where each chat room is modeled as a `channel` (similar to Discord channels). In single-agent mode, the agent handles all incoming user messages directly. In multi-agent mode, each user message should trigger a centralized decision pass: an LLM evaluator scores every candidate agent for task fit and confidence, then the backend selects the top-scoring agent to answer.

## Goals
1. Define a clear domain model for `channel`, `agent`, and `decision_result`.
2. Support both single-agent direct mode and multi-agent arbitration mode under one unified pipeline.
3. Use a single LLM decision prompt to score all candidate agents for the current message.
4. Select the highest-confidence agent as winner; if scores tie, route to a configured default agent.
5. Ensure decisions are observable, auditable, and testable.

## Implementation Plan (phased)

### Phase 1: Domain and protocol definition
- Add `channel` as top-level message routing scope.
- Define LLM scoring output schema for each candidate agent:
  - `agent_id`
  - `score` (0-1)
  - `confidence` (0-1)
  - `reason`
- Define arbitration result schema:
  - `selected_agent_id`
  - `selected_score`
  - `tie_detected` (boolean)
  - `tie_agent_ids`
  - `fallback_to_default_agent` (boolean)
  - `decision_reason`
  - `trace_id`.

### Phase 2: Routing engine behavior
- Implement unified channel message intake pipeline:
  1. ingest message,
  2. load channel participants,
  3. run mode check:
     - if one active agent => direct dispatch,
     - if many active agents => LLM scoring arbitration.
- Build one structured LLM prompt that receives:
  - user message,
  - channel context,
  - candidate agent profiles/capabilities.
- Parse structured LLM output and rank agents by score.

### Phase 3: Decision policy
- Select the agent with the highest score/confidence.
- If two or more agents share the same top score, route to `default_agent_id`.
- If LLM output is invalid or incomplete, route to `default_agent_id` and mark as decision fallback.
- Persist scoring table and final decision trace for replay/debugging.

### Phase 4: Operations and quality
- Add structured logs/metrics:
  - arbitration latency,
  - average score by agent,
  - win rate by agent,
  - tie rate,
  - default-agent fallback rate.
- Add acceptance tests for:
  - single-agent channel,
  - multi-agent highest-score selection,
  - tie => default agent,
  - invalid LLM judge output => default agent.

## Acceptance Criteria
1. In a channel with exactly one active agent, every user message is directly dispatched to that agent without arbitration.
2. In a channel with two or more active agents, each user message triggers one LLM scoring decision that evaluates all candidate agents.
3. The selected responder is always the candidate with the highest score.
4. If the top score is tied, the system always routes to the configured default agent.
5. Every arbitration stores a machine-readable decision record with per-agent scores, winner, and trace ID.
6. If LLM arbitration output cannot be parsed, the system falls back to the default agent and records fallback reason.

## Validation Commands
- `npm run type-check`
- `npm run test`
- `flutter analyze` (if mobile integration changes are involved)
