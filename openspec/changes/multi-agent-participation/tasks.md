# Tasks: Multi-Agent Participation Probability Management

## Backend / Domain

- [x] Add `AgentParticipant` model to `packages/agent_sdk_contract` with `agentId`, `agentName`, `isEnabled`, `probability` fields and `toMap`/`fromMap` serialisation
- [x] Add `SessionParticipants` immutable collection to `packages/agent_sdk_contract` with `.active` filter and serialisation
- [x] Add `SessionCoordinator` abstract interface to `packages/agent_sdk_contract` (`addParticipant`, `removeParticipant`, `updateProbability`, `setEnabled`, `decideProactiveSpeakers`)
- [x] Implement `ParticipantManager` in `packages/agent_core` with injected `Random` and probability-based `decideProactiveSpeakers()`
- [x] Add `agentId` and `agentName` optional fields to `Message` in `packages/chat_domain` (omitted from serialisation when null)
- [x] Add use-case spec `tests/usecases/multi_agent_session.yaml` with session management, proactive speaking, probability adjustment, and message attribution scenarios
- [x] Add unit tests for `ParticipantManager` in `packages/agent_core/test/`
- [x] Add unit tests for `AgentParticipant` / `SessionParticipants` in `packages/agent_sdk_contract/test/`
- [x] Add unit tests for `Message` agent attribution fields in `packages/chat_domain/test/`

## UI Layer

- [x] Create `SessionSettingsPage` Flutter widget in `apps/mobile_chat_app` with agent participant list
- [x] Implement `AgentParticipantTile` with enable/disable checkbox and probability slider (0–100%)
- [x] Wire session settings page to `SessionCoordinator` (read participants, call `setEnabled` / `updateProbability`)
- [x] Add navigation entry point: Session → Settings → Agent Participants
- [x] Display agent attribution in conversation message list (avatar/chip when `agentId` is non-null)

## Integration

- [x] Integrate `ParticipantManager.decideProactiveSpeakers()` into the chat session dispatch after each user message
- [x] For each decided speaker, invoke the agent session and emit attributed `Message` with `agentId`/`agentName`
