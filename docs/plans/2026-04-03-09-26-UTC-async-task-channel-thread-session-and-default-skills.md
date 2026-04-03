# Async Task Transport + Channel/Thread/Session + Default Skills Baseline Plan

## Background
Current chat interaction is mostly request/stream-response oriented and does not provide a durable asynchronous task lifecycle under unstable networks.
At the same time, routing concepts need stronger identity boundaries: Channel, Thread, and Session must be first-class entities across backend and client.

We align semantics as follows:
- users converse with **bots**,
- bots are conversation participants and routable responders,
- each bot can reference one or more **skills**,
- skills provide prompt/capability profiles and callable functions inside agent loops,
- skills are **not** conversation participants.

This baseline introduces two default skills shared by backend and client:
- `conversation`
- `image_generation`

This plan is complementary to `2026-04-03-05-03-UTC-multi-agent-channel-arbitration.md`:
- This document defines transport, entity identity, and default skill baseline.
- The arbitration document defines how one bot is selected when multiple bots are active.

## Goals
1. Define an asynchronous task lifecycle contract that survives transient client/network interruptions.
2. Define Channel/Thread/Session entities and stable IDs used by both backend and client.
3. Define a default skill baseline (`conversation`, `image_generation`) and how bots bind to skills.
4. Keep scope minimal and implementation-ready without introducing non-essential orchestration features.

## Implementation Plan (phased)

### Phase 1: Core entity model (Channel / Thread / Session / Bot)
- Define entity responsibilities and ownership:
  - `channel_id`: top-level collaboration/routing scope.
  - `thread_id`: sub-conversation scope under a channel.
  - `session_id`: runtime interaction instance bound to one thread.
  - `bot_id`: conversation participant identity for routing and attribution.
- Define required relationships:
  - one channel contains many threads,
  - one thread contains many sessions over time,
  - each user-visible message and task references channel/thread/session IDs and resolved `bot_id`.
- Define default resolution rules:
  - if no channel is specified, route to `default_channel_id`.
  - if no thread is specified, route/create default thread under the channel.

### Phase 2: Async task lifecycle contract
- Introduce task envelope fields:
  - `task_id`, `channel_id`, `thread_id`, `session_id`,
  - `bot_id`, `resolved_skill_id`,
  - `created_at`.
- Define minimal state machine:
  - `accepted` -> `dispatched` -> (`completed` | `failed` | `cancelled`).
- Define reliability semantics:
  - idempotent submission key for safe retries,
  - backend acknowledgement on acceptance,
  - resumable client sync by cursor/checkpoint for missed updates.
- Define transport behavior:
  - pull-based state sync is source of truth,
  - push/stream events are optional acceleration only.

### Phase 3: Default skills baseline and bot binding (backend + client unified)
- Define canonical default skills:
  - `conversation`
  - `image_generation`
- Define bot-skill binding contract:
  - each bot has `default_skill_id`,
  - each bot may have additional callable skills,
  - skill invocation happens inside the selected bot's agent loop.
- Define default selection policy:
  - if bot is selected and no skill override is provided, use bot's `default_skill_id`,
  - if requested skill is unavailable/disabled for that bot, fallback to `conversation` and record reason.
- Define shared metadata:
  - Bot metadata: `bot_id`, `display_name`, `default_skill_id`.
  - Skill metadata: `skill_id`, `description`, `input_mode`, `output_mode`, `is_default`.
- Define client UX contract:
  - bot switcher controls conversation participants,
  - message/task record persists resolved `bot_id` and `resolved_skill_id` for replay and audit.

### Phase 4: Integration boundaries with arbitration plan
- Keep arbitration as a separate decision stage; do not merge into transport logic.
- Ensure arbitration consumes the same entity IDs and bot registry defined here.
- Ensure fallback semantics are aligned:
  - this plan: transport-level/default-skill resolution within selected bot,
  - arbitration plan: decision-level default bot fallback.

## Acceptance Criteria
1. A client can submit a message/task and receive an `accepted` acknowledgement with a durable `task_id`, even if response generation is not finished yet.
2. After simulated network interruption and reconnect, the client can recover missed task/message updates using cursor/checkpoint sync without data loss.
3. Every stored task/message record includes `channel_id`, `thread_id`, `session_id`, and resolved `bot_id`.
4. If no skill override is specified for a selected bot, backend resolves to that bot's `default_skill_id` deterministically.
5. If `image_generation` is requested and available for the selected bot, the task is routed accordingly; if unavailable, fallback to `conversation` is recorded.
6. Skills are not treated as conversation participants in routing decisions; bot selection remains the conversation-level decision unit.

## Validation Commands
- `npm run type-check`
- `npm run test`
- `flutter analyze`
