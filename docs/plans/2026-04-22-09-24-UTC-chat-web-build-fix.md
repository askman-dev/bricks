# Chat web build fix plan

## Background
The mobile chat app web build currently fails during dart2js compilation with errors in chat navigation and chat screen code. Reported failures include a missing required `prompt` parameter when constructing `ChatAgentItem`, a list type mismatch for mapped agent items, and missing `_openClawSlashCommands` / `_currentComposerModelLabel` members in `_ChatScreenState`.

## Goals
- Restore a successful web compile for `apps/mobile_chat_app`.
- Ensure chat navigation agent construction matches current model signatures.
- Ensure chat screen references only defined state fields/methods.
- Keep behavior coherent for OpenClaw and non-OpenClaw chat contexts.

## Implementation Plan (phased)
1. Inspect the relevant Dart files and model definitions to identify signature and type expectations.
2. Patch `chat_navigation_page.dart` to provide required fields and resolve list typing.
3. Patch `chat_screen.dart` to replace/restore missing members for slash commands and composer model labels.
4. Run bootstrap (`./tools/init_dev_env.sh`) and then targeted verification commands from the correct package directory.
5. If functionality changed, evaluate and update code maps; otherwise document why updates are unnecessary.

## Acceptance Criteria
- `flutter` analysis/build checks for `apps/mobile_chat_app` no longer report the listed compile errors.
- `ChatAgentItem` construction includes required named parameters expected by the current type.
- `_ChatScreenState` has valid references for slash command source and composer model label.
- Any code map update decision is documented in the final report.
