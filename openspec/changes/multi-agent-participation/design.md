# Design: Multi-Agent Participation Probability Management

## Architecture Overview

The feature is split into three layers following the existing package structure:

```
apps/mobile_chat_app        ← UI: session settings page (remaining)
packages/agent_core         ← ParticipantManager (implemented)
packages/agent_sdk_contract ← AgentParticipant / SessionCoordinator (implemented)
packages/chat_domain        ← Message attribution (implemented)
packages/workspace_fs       ← AgentsRepository (from issue #23, reused here)
```

## Domain Layer (Implemented)

### `AgentParticipant`

```dart
class AgentParticipant {
  final String agentId;      // matches AgentDefinition.name from issue #23
  final String agentName;    // display name from .md frontmatter
  final bool isEnabled;      // default true  — agent is "in the session"
  final double probability;  // 0.0–1.0, default 0.0 — agent is silent until the user sets a value
}
```

The `agentId` field intentionally mirrors the `name` field in issue #23's agent `.md` files, keeping a single source of truth for agent identity.

`isEnabled` and `probability` are complementary, not contradictory:
- `isEnabled = true` means the agent is present in the session (visible in the settings list).
- `probability = 0.0` means it never speaks proactively — the user must raise this value to opt in.
- `isEnabled = false` is a quick "mute" that suppresses an agent without losing its probability setting, so it can be re-enabled later with the same value.

### `ParticipantManager.decideProactiveSpeakers()`

Evaluates each enabled participant independently:
- `probability == 0.0` → never speaks
- `probability == 1.0` → always speaks
- Otherwise → speaks if `Random.nextDouble() < probability`

`Random` is injected for deterministic testing.

### `Message` Attribution

`Message.agentId` and `Message.agentName` are optional fields. They are:
- Set when an agent produces a response
- `null` for user messages
- Omitted from `toMap()` serialisation when null (backward-compatible)

## UI Layer (Remaining)

### Session Settings Page

A new Flutter page reachable from Session → Settings:

```
SessionSettingsPage
└── AgentParticipantList
    └── AgentParticipantTile (per agent)
        ├── Checkbox (isEnabled toggle)
        ├── Agent name / avatar
        └── ProbabilitySlider (0–100%)
```

The page reads the current `SessionParticipants` from the session's `SessionCoordinator` and writes back via `setEnabled()` / `updateProbability()`.

### Visual Attribution in Conversation

In the message list, messages with non-null `agentId` display:
- A small agent avatar or coloured chip
- The agent name as a label above/beside the bubble

This is handled at the message widget level; no changes needed to domain models.

### Integration into Chat Session Flow

After each user message is dispatched:
1. Call `ParticipantManager.decideProactiveSpeakers()` to obtain a list of agent IDs.
2. For each speaker, invoke the corresponding agent session (using `AgentSession` from issue #23's contracts).
3. Emit each agent response as a `Message` with `agentId` and `agentName` set.

## Open Questions (from issue #24)

| Question | Decision |
|----------|----------|
| Probability trigger: per user message, time-based, or both? | Per user message only (simplest; time-based deferred). |
| Probabilities independent or normalised? | Independent (0–100% each). |
| Multiple agents triggered simultaneously? | All speak; ordering by `participants` list insertion order. |
| Default probability for new agents? | 0.0 (silent by default; user opts in). |
