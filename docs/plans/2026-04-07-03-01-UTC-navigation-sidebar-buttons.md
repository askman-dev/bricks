# Background
The chat navigation drawer currently exposes settings and channel creation actions in multiple places, including a three-button row and additional duplicated entries further down the panel. This causes visual clutter and inconsistent action placement.

# Goals
- Move the Settings entry into the same row as the Navigation title, aligned to the right side.
- Place the New Channel action on that same title row, to the right of Settings, making it the rightmost action.
- Remove the old three-button action row (Settings / Sessions / New Channel).
- Remove the extra New Channel button below “Manage Agents”.
- Keep a section header labeled “频道” in the same vertical area where the removed lower New Channel button used to be, and treat it as the header for the channel list.
- Ensure only one Settings entry remains in the drawer.

# Implementation Plan (phased)
1. Update `ChatNavigationPage` header layout to include title-row action buttons (Settings + New Channel) on the right.
2. Delete the legacy action row containing Settings / Sessions / New Channel.
3. Remove duplicated lower controls (extra New Channel button and trailing Settings list tile).
4. Add a localized channels section label (`频道`) above the channel list where the lower New Channel button was.
5. Update widget tests to reflect the new UI structure and verify deduplication.

# Acceptance Criteria
- The drawer shows a single Settings entry, rendered as an icon button on the Navigation title row.
- The drawer title row contains New Channel to the right of Settings (rightmost action).
- No three-button action row is present.
- No New Channel button appears under “Manage Agents”.
- A “频道” section heading appears above the channel list.
- Relevant Flutter widget tests pass.
