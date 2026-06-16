# Scope Instructions Config

## Background

The chat screen currently has multiple conversation scopes: a channel and, when selected, a sub-section under that channel. A channel can define broad context, while a sub-section can narrow the current topic further. Prompt-style configuration should therefore belong to the active conversation scope model rather than only to channels.

The entry point should not be placed inside the channel switcher, because the action configures the current chat context and may include both channel-level and sub-section-level settings. A stable action in the conversation area's top-right controls better communicates that this is a configuration action for the current chat view.

## Goals

- Add a top-right conversation config action in the chat area.
- Provide a config UI with tabs for channel configuration and current sub-section configuration.
- Allow channel-level `Instructions` to describe the broad context/topic for the channel.
- Allow sub-section-level `Instructions` to describe the narrower context/topic for the current sub-section.
- Hide or disable sub-section configuration when the current sub-section is the main section.
- Apply the relevant instructions to default-route chat requests without replacing the selected Agent prompt.
- Keep OpenClaw routing behavior unchanged.

## Implementation Plan

1. Add a conversation config action to the chat app bar's right-side controls, separate from the channel dropdown and sub-section dropdown.
2. Build a configuration dialog or sheet with two tabs: `Channel` and `Current Section`.
3. In the `Channel` tab, show an `Instructions` text field for the active channel with helper copy explaining that it sets context and customizes what target/topic the channel discusses.
4. In the `Current Section` tab, show an `Instructions` text field only when the active section is a sub-section; for the main section, show a non-editable state explaining that main uses channel instructions only.
5. Extend chat scope settings persistence so both `channel` scope rows and `thread`/sub-section scope rows can store optional instructions independently of router and node settings.
6. Hydrate channel and sub-section instructions in the Flutter chat client, save edits optimistically with rollback on failure, and preserve existing router/node configuration when instructions are saved or cleared.
7. Compose runtime default-route prompts from the selected Agent prompt plus active channel instructions plus active sub-section instructions, with sub-section instructions acting as additional narrower context.
8. Add focused backend and Flutter tests for persistence, hydration, request payloads, and prompt composition behavior.
9. Update code maps because this changes chat feature entry points and chat request logic.

## Acceptance Criteria

- Given the user is in any chat scope, when they look at the conversation area's top-right controls, then they can open a config action that is not part of the channel dropdown.
- Given the config UI is open, when the active scope is any channel, then the `Channel` tab lets the user edit and save channel `Instructions`.
- Given the config UI is open on the main section, when the user opens the section tab, then section instructions are not editable and the UI indicates that the main section uses channel instructions only.
- Given the config UI is open on a sub-section, when the user opens the section tab, then they can edit and save instructions for that current sub-section.
- Given saved channel instructions exist, when the app reloads, then the channel tab restores the saved value.
- Given saved sub-section instructions exist, when the user returns to that sub-section, then the section tab restores the saved value.
- Given both channel and sub-section instructions exist, when a default-route message is sent from that sub-section, then the request includes Agent prompt context plus both instruction scopes.
- Given only channel instructions exist, when a default-route message is sent from the main section, then the request includes Agent prompt context plus channel instructions.
- Given instructions are cleared, when the user saves and reloads, then the cleared scope no longer contributes prompt context.
- Given a scope uses OpenClaw routing, when instructions are saved or messages are sent, then OpenClaw routing and node selection behavior remains unchanged.

## Validation Commands

- `./tools/init_dev_env.sh`
- `npm test -- --runInBand`
- `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
