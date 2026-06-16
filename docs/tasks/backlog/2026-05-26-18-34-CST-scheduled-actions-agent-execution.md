# Scheduled Actions and Agent Execution

## Background

### Context

Bricks already has a conversation-driven Agent loop that can call internal tools, persist chat messages, and update channel/thread resources. The backend is deployed on Vercel as serverless Node functions, so scheduled work should not rely on a long-lived in-process scheduler such as `node-cron`.

The product direction is to support scheduled AI actions similar to ChatGPT Tasks or Gemini Scheduled actions: users create and manage a scheduled action through conversation, and when the schedule fires Bricks starts normal Agent execution on the user's behalf.

### Problem

The schedule layer, the Agent/tool layer, and future scriptable skill runtimes must stay decoupled:

- Scheduled actions should not be tied directly to Genkit.
- Genkit should be one possible runtime for scriptable skills, not the scheduler runtime.
- Users should manage scheduled actions through conversation tools, not through a separate hidden admin path.
- A scheduled trigger should start ordinary Agent execution so the run can use any available tool or skill.

### Motivation

This keeps scheduled actions as a first-class resource while preserving the existing Agent/tool model. It also leaves room for scriptable Agent pipelines later: a scheduled action may trigger a prompt that invokes a skill backed by Genkit, but it may also invoke normal Bricks tools such as todos, resources, channel/thread tools, or future skills.

## Goals

- Add scheduled actions as a first-class user resource.
- Let users create, list, update, pause, resume, and delete scheduled actions through Agent tools.
- Use Vercel Cron only as a fixed tick that finds due scheduled actions.
- When an action is due, create a run record and start the existing Agent execution path with the scheduled prompt.
- Keep scheduled actions independent from Genkit and other specific skill runtimes.
- Preserve user identity, channel, and thread context for scheduled executions.
- Make scheduled action execution observable, retryable, and safe against duplicate claims.

## Implementation Plan

1. Add the scheduled action storage model.
   - Create a migration for `scheduled_actions`.
   - Store `user_id`, target `channel_id`, target `thread_id`, `title`, `prompt`, schedule expression, timezone, `next_run_at`, status, and timestamps.
   - Use a stable status enum such as `active`, `paused`, and `deleted`.
   - Keep display title separate from the schedule identity.

2. Add scheduled action run tracking.
   - Create a migration for `scheduled_action_runs`.
   - Record each trigger attempt with `scheduled_action_id`, `user_id`, target scope, scheduled fire time, status, timestamps, error text, and the chat task/message identifiers produced by execution.
   - Use run statuses such as `queued`, `running`, `completed`, and `failed`.
   - Add enough metadata to inspect what happened after a scheduled trigger.

3. Implement a scheduled action service.
   - Add CRUD helpers for scheduled actions scoped by `user_id`.
   - Add due-action querying with a small batch limit.
   - Add a claim/lease mechanism so the same due action is not executed twice when multiple cron requests overlap.
   - Compute the next run time after each successful claim or completion.
   - Keep schedule parsing and timezone handling inside this service boundary.

4. Expose scheduled action internal tools.
   - Add tools such as `scheduled_action_create`, `scheduled_action_list`, `scheduled_action_get`, `scheduled_action_update`, `scheduled_action_pause`, `scheduled_action_resume`, and `scheduled_action_delete`.
   - Register them with the existing internal tool mechanism used by the Agent loop.
   - The tools write to `scheduled_actions`; the scheduler is not the only writer.
   - Tool responses should be concise and structured so the Agent can confirm the action to the user.

5. Add a scheduler tick endpoint.
   - Add a protected backend route such as `GET /api/cron/scheduled-actions`.
   - Configure Vercel Cron in the root Vercel configuration to call this path on a fixed cadence.
   - The endpoint should query due actions, claim a bounded batch, create `scheduled_action_runs`, and enqueue or start Agent execution for each claimed action.
   - The endpoint should return a small operational summary, not user-facing content.

6. Start normal Agent execution from due actions.
   - Convert each due scheduled action into a normal Agent input using the stored `prompt`, `user_id`, `channel_id`, and `thread_id`.
   - Persist a scheduled-origin message or task marker so the conversation history shows why the Agent ran.
   - Reuse the existing async chat/Agent pipeline rather than adding a separate scheduler-only executor.
   - Mark the scheduled action run completed or failed based on the Agent execution result.

7. Keep skill runtimes pluggable.
   - Do not store Genkit-specific fields on `scheduled_actions`.
   - If a scheduled prompt should invoke a scriptable pipeline, it should do so through the normal skill/tool selection path.
   - Define Genkit-backed skills later as entries in the skill/runtime layer, not as scheduler primitives.

8. Add UI/API visibility.
   - Add REST endpoints for listing and inspecting scheduled actions if the UI needs a management surface.
   - The first usable path can remain conversation-first, but the data model should support a future Scheduled Actions screen.
   - Show scheduled action results in the target channel/thread as normal conversation output.

9. Update documentation and code maps.
   - Update `docs/tasks/backlog/2026-05-26-scheduled-agent-tasks.md` or supersede it with this plan.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` because this change adds feature entry points, business logic, migrations, tools, and scheduled execution.

## Acceptance Criteria

- A user can ask Bricks to create a scheduled action through chat, and the Agent calls a scheduled action tool that persists the action.
- A user can list, update, pause, resume, and delete their scheduled actions through chat tools.
- A due scheduled action is claimed once, creates a `scheduled_action_runs` record, and starts normal Agent execution in the configured channel/thread.
- A scheduled action execution can call any normal Agent tool or skill; it is not tied to Genkit.
- Genkit-backed skills, if added later, are invoked through the skill/tool layer rather than through scheduler-specific code.
- Duplicate cron invocations do not execute the same due action twice.
- Scheduled action results are visible in the target conversation context.
- Failed scheduled action runs are recorded with an inspectable failure reason.
- The system remains compatible with Vercel serverless deployment and does not depend on an in-process long-lived scheduler.

## Validation Commands

- `cd apps/node_backend && npm test -- src/services/localAgentLoopService.test.ts src/routes/chat.test.ts`
- `cd apps/node_backend && npm test -- src/db/migrate.test.ts`
- `cd apps/node_backend && npm run type-check`
- `npx js-yaml docs/code_maps/feature_map.yaml >/dev/null && npx js-yaml docs/code_maps/logic_map.yaml >/dev/null`
- `git diff --check`
