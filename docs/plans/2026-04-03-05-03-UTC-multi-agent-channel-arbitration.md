# Multi-Bot Channel Arbitration Plan

## Background
We keep concept layers explicit and non-overlapping:
- **Conversation layer**: users interact with Bots.
- **Runtime layer**: Bots run on Agent execution loops.
- **Capability layer**: Skills are callable capabilities/prompts used by agents; Skills are **not** conversation participants.

Each Bot can be associated with one or more Skills, and one default Skill profile can define the bot's baseline prompt/capability posture.

This plan stays intentionally narrow: arbitration policy only.
It assumes Channel/Thread/Session identities and asynchronous task transport are defined by companion plans.

## Goals
1. Define a clear arbitration model for selecting one bot per user turn within a channel context.
2. Support both direct mode (single active bot) and arbitration mode (multiple active bots) under one routing pipeline.
3. Use a single LLM judge pass to score all candidate bots for the current message.
4. Route ties and invalid judge output to a configured default bot deterministically.
5. Ensure decisions are observable, auditable, and testable.

## Implementation Plan (phased)

### Phase 1: Domain and protocol definition
- Define bot identity schema:
  - `bot_id`
  - `display_name`
  - `default_skill_id` (default prompt/capability profile for this bot)
- Define LLM scoring output schema for each candidate bot:
  - `bot_id`
  - `score` (0-1)
  - `confidence` (0-1)
  - `reason`
- Define arbitration result schema:
  - `selected_bot_id`
  - `selected_score`
  - `tie_detected` (boolean)
  - `tie_bot_ids`
  - `fallback_to_default_bot` (boolean)
  - `decision_reason`
  - `trace_id`

### Phase 2: Routing engine behavior
- Implement unified message routing decision stage:
  1. ingest message context,
  2. load active bots for the current channel/thread/session,
  3. run mode check:
     - if one active bot => direct dispatch,
     - if many active bots => LLM judge arbitration.
- Build one structured LLM prompt that receives:
  - user message,
  - channel/thread/session context summary,
  - candidate bot profiles (including default skill references).
- Parse structured judge output and rank bots by score/confidence.

### Phase 3: Decision policy
- Select the bot with the highest score/confidence.
- If two or more bots share the same top score, route to `default_bot_id`.
- If judge output is invalid/incomplete, route to `default_bot_id` and mark as fallback.
- Persist per-bot scoring and final decision trace for replay/debugging.

### Phase 4: Operations and quality
- Add structured logs/metrics:
  - arbitration latency,
  - average score by bot,
  - win rate by bot,
  - tie rate,
  - default-bot fallback rate.
- Add acceptance tests for:
  - single-bot direct routing,
  - multi-bot highest-score selection,
  - tie => default bot,
  - invalid judge output => default bot.

## Acceptance Criteria
1. In a channel/thread/session with exactly one active bot, each user message is directly dispatched to that bot without arbitration.
2. In a channel/thread/session with two or more active bots, each user message triggers one judge decision that evaluates all candidate bots.
3. The selected responder is always the candidate bot with the highest score.
4. If the top score is tied, the system always routes to the configured default bot.
5. Every arbitration stores a machine-readable decision record with per-bot scores, winner, and trace ID.
6. If arbitration output cannot be parsed, the system falls back to the default bot and records the fallback reason.

## Validation Commands
- `npm run type-check`
- `npm run test`
- `flutter analyze` (if client integration changes are involved)
