# Channel Output Tone and Input Grammar Fixer

## Background

Bricks should not copy Claude Code lifecycle hooks as a product concept. The
current design direction is to keep a standard skill layer and let Bricks bind
those skills to conversation settings, system tools, and UI surfaces.

For this task, the product scope is intentionally narrow:

- Channel output tone.
- Custom channel output tone.
- Channel input grammar fixer.

Reply action buttons are related, but they are not part of the current scope.
They are tracked separately in
`docs/backlog/2026-06-17-reply-action-skill-bindings.md`.

## Goals

- Add channel-scoped output tone as a first-class setting.
- Support three built-in output tone presets: Direct, Socratic, and Rhetorical.
- Support custom output tone as a user-defined setting type.
- Programmatically inject the current channel output tone into the assembled
  system prompt for future assistant replies.
- Add a channel-scoped input grammar fixer setting.
- Let model/tool calls update these settings through explicit system tools.
- Keep grammar suggestions display-only; they must not replace the user's input
  or affect the main model request.
- Allow settings to change after a conversation has started, with changes
  affecting future messages only.

## Architecture Decisions

### Skill and Binding Model

Skills describe reusable capability. Bricks-specific bindings decide where a
skill is used and what state it changes.

For this task:

- Output tone is not a per-response model invocation skill.
- Output tone tools update channel settings.
- Prompt assembly reads channel settings and injects them into the system
  prompt.
- Input grammar fixer is a channel setting that controls whether Bricks runs a
  lightweight grammar-check request beside the main conversation flow.

### Output Tone Setting

The channel stores output tone as structured state:

```text
channel.outputTone =
  preset: direct | socratic | rhetorical
  or
  custom: <user-defined instruction>
```

Preset meanings:

- Direct: rigorous, efficient, concise, not exaggerated, and low on decorative
  rhetoric.
- Socratic: guide the user through focused questions and reflective prompts.
- Rhetorical: use richer language, stronger rhythm, and more expressive
  phrasing while preserving accuracy.

Direct is the default. Concise, no-hype, and similar requests should converge on
Direct rather than becoming separate presets.

### Output Tone Tools

The system should expose tools that can update channel tone settings:

```text
set_channel_output_tone
- preset: direct | socratic | rhetorical

set_channel_custom_output_tone
- instruction: string
```

These tools write channel state. They do not generate normal assistant content
by themselves.

### Prompt Assembly

Every future assistant request in the channel should be assembled from:

```text
base system prompt
+ channel instruction
+ current channel output tone
```

Only the latest channel output tone should control behavior. Historical tone
changes may remain visible in conversation history as events, but prompt
assembly should not replay every historical tone change.

### Input Grammar Fixer Setting

The channel stores a simple boolean:

```text
channel.inputGrammarFixerEnabled = true | false
```

The system should expose a tool:

```text
set_channel_input_grammar_fix
- enabled: boolean
```

When enabled, Bricks may run one lightweight grammar request for English user
input. The main assistant reply should continue using the original user input.

Grammar fixer results should be compact:

```json
{ "status": "accepted", "suggestion": null }
```

or:

```json
{ "status": "suggested", "suggestion": "Corrected user-facing text." }
```

Accepted inputs should show a small positive signal, such as an icon. Suggested
inputs should display the suggestion string. Grammar fixer failures should stay
quiet and should not pollute the main chat.

### Update Semantics

Settings are mutable channel state. Users may change them after a conversation
has started.

- New output tone settings affect future assistant replies only.
- Existing assistant replies are not rewritten.
- New grammar fixer settings affect future user inputs only.
- Existing grammar suggestions or accepted signals may remain as historical UI
  results.
- Setting changes are persisted as channel state and should refresh the visible
  settings UI through the existing scope-settings invalidation path.

## Implementation Plan

1. Inspect the existing channel instruction setting model, persistence path, and
   prompt assembly path.
2. Add structured channel output tone storage beside the existing channel
   instruction setting.
3. Add the three preset tone definitions and custom tone representation.
4. Add system tools for setting preset output tone and custom output tone.
5. Render the current channel output tone into the system prompt during prompt
   assembly.
6. Add channel input grammar fixer storage.
7. Add the system tool for enabling or disabling input grammar fixer.
8. Add the lightweight grammar-check request path and compact accepted/suggested
   result contract.
9. Add UI rendering for accepted grammar signal and suggested correction text on
   user input.
10. Update code maps if feature entry points, business logic, tests, or docs
    indexes change during implementation.

## Acceptance Criteria

- A channel can store Direct, Socratic, Rhetorical, or custom output tone.
- Direct is the default channel output tone.
- Users can ask the assistant to change the channel output tone, and the model
  can call a system tool that updates the channel setting.
- Future assistant replies in the channel receive the current output tone through
  programmatic system prompt assembly.
- Tone changes after a conversation starts affect only future replies.
- A channel can enable or disable input grammar fixer through a system tool.
- When grammar fixer is enabled, English user input can receive either an
  accepted signal or a displayed suggestion.
- Grammar suggestions do not replace the user's original input and do not change
  the main model request.
- Grammar fixer failures do not create visible chat errors.
- Reply action buttons remain out of current scope.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter analyze`
- `cd apps/mobile_chat_app && flutter test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- src/services/chatRouterService.test.ts src/services/localAgentLoopService.test.ts src/routes/chat.test.ts`
- `cd apps/node_backend && npm test` when a test database URL is configured.
