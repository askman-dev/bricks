# Scope Config Thread Label

## Background

The chat conversation config dialog currently presents two tabs as `Channel` and
`Section`. The product concept has moved to `Thread`, and the underlying scope
model already uses `thread` for persisted settings.

## Goals

- Rename user-facing `Section` labels in the conversation config dialog to
  `Thread`.
- Keep the `Instructions` field label fully visible in the dialog.
- Add English `Rename` and `Archive` actions to the top channel dropdown.
- Keep default channels protected from rename and archive actions.
- Rename the Navigation channel creation button to `New Channel`.
- Constrain the top channel dropdown height so long channel lists scroll inside
  the menu.
- Keep storage/API scope names unchanged.
- Update code maps so the UI acceptance notes use the current product language.

## Implementation Plan

1. Update the scope config dialog tab, hint text, disabled main-scope message,
   and save-error wording from section to thread.
2. Add enough top padding around the multiline instruction fields so their
   floating labels are not clipped by the tab view.
3. Add a channel dropdown function group before the channel list and route the
   actions to the existing channel rename/archive handlers.
4. Disable channel rename/archive menu entries when the active channel is the
   default channel.
5. Update the Navigation channels tab create button and its widget test to use
   English copy.
6. Add a responsive max-height constraint to the top channel popup menu.
7. Leave existing private implementation names alone unless they directly render
   user-facing copy.
8. Update feature and logic code maps for the `Channel / Thread` wording and
   channel dropdown management actions.

## Acceptance Criteria

- Opening the top-right conversation config dialog shows `Channel` and `Thread`
  tabs.
- In the main thread, the thread tab explains that the main thread uses channel
  instructions only and cannot be saved.
- In a child thread, the thread tab describes thread-specific narrower context.
- The `Instructions` label is fully visible above both multiline fields.
- The top channel dropdown shows `Rename` and `Archive` actions above the
  channel list.
- `Rename` and `Archive` are disabled for the default channel.
- Non-default channel rename and archive actions use the same persistence paths
  as the navigation sidebar actions.
- The Navigation channels tab create button reads `New Channel`.
- Long channel dropdown lists stay within a bounded height and scroll inside the
  popup.
- Existing persisted channel/thread instruction behavior is unchanged.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter analyze`
