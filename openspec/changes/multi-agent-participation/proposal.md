# Proposal: Multi-Agent Participation Probability Management in Sessions

## What

Enable configurable probability-based participation for multiple agents within a single chat session. Agents "at the table" speak proactively based on adjustable probability parameters, without requiring explicit @mention from the user.

## Why

Users working with multiple AI personas benefit from a natural conversation experience where agents contribute at configurable rates. Mobile-first interaction design requires a dedicated session settings page rather than slash commands.

## Non-goals

- Agent definition authoring (covered by issue #23)
- Time-based or event-triggered participation (probability is evaluated per user message only)
- Normalized probability (probabilities are independent, 0–100% each)

## Key Design Decisions

- Each agent participant has an independent probability (0.0–1.0); they are not normalized to sum to 1.
- Agent identity (`agentId`, `agentName`) reuses the definitions from issue #23's `.md` frontmatter — no duplication.
- Proactive speaking is evaluated after every user message; disabled agents are never triggered.
- Multiple agents triggered simultaneously all produce responses; no queue or random-pick filtering at this layer.
- Default probability for a newly added agent is 0.0 (silent by default). `isEnabled` defaults to `true` so the agent is visible in the settings list; it only speaks once the user raises its probability above 0. `isEnabled = false` is a quick mute that preserves the probability value.

## Implementation Status (as of 2026-03-13)

### ✅ Completed — Backend domain layer

| Component | Location | Description |
|-----------|----------|-------------|
| `AgentParticipant` | `packages/agent_sdk_contract` | Model: agentId, agentName, isEnabled, probability (0.0–1.0) |
| `SessionParticipants` | `packages/agent_sdk_contract` | Immutable collection; exposes `.active` filter |
| `SessionCoordinator` | `packages/agent_sdk_contract` | Interface for managing participants and deciding speakers |
| `ParticipantManager` | `packages/agent_core` | Implements `SessionCoordinator`; `decideProactiveSpeakers()` uses `Random` injection |
| `Message.agentId/agentName` | `packages/chat_domain` | Optional attribution fields; omitted from serialisation when null |
| Use-case spec | `tests/usecases/multi_agent_session.yaml` | Natural-language acceptance specs |

### ❌ Remaining — UI layer

| Component | Notes |
|-----------|-------|
| Session settings page | Mobile-friendly Flutter page: agent list + per-agent controls |
| Agent enable/disable checkbox | Toggle `AgentParticipant.isEnabled` via `SessionCoordinator.setEnabled()` |
| Probability slider | 0–100% slider mapped to 0.0–1.0; calls `SessionCoordinator.updateProbability()` |
| Visual attribution in conversation | Display agent avatar/tag next to messages where `agentId` is non-null |
| Integration into chat session flow | Wire `ParticipantManager.decideProactiveSpeakers()` into message dispatch |
