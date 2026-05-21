# Channel Dropdown Height Evidence Case

## User-Visible Case

In the chat screen, clicking the active channel name opens a channel dropdown.
When many channels exist, the dropdown should stay within a reasonable maximum
height and scroll internally instead of growing too tall.

## Baseline Behavior To Prove

Before a fix, a long channel list can make the channel dropdown too tall.

## Fixed Behavior To Prove

After the fix:

- the channel dropdown opens from the active channel name
- `Rename` and `Archive` remain visible at the top of the menu
- the menu height is bounded
- wheel scrolling changes menu contents inside the popup
- screenshots prove the opened and scrolled states

## Required Data

The fixture user must have enough channel display names to overflow the channel
popup. The flow may create extra channel names with this prefix:

```text
E2E Dropdown <run-id>
```

Rows are scoped to `FIXTURE_USER_ID`.

## Required Environment

Read `.env.local` from the repository root.

Required variables:

```text
TURSO_DATABASE_URL
TURSO_AUTH_TOKEN
JWT_SECRET
BRICKS_TEST_TOKEN
BRICKS_API_BASE_URL
FIXTURE_USER_ID
```

## Run

From the repository root:

```sh
tools/evidence/channel_dropdown_height/run.sh
```

## Evidence Output

```text
.cache/evidence/channel-dropdown-height/<run-id>/
```

Expected files:

```text
summary.json
browser-events.json
api-channel-names-before.json
api-channel-names-after-fixture.json
<run-id>-00-login-or-chat.png
<run-id>-01-before-menu.png
<run-id>-02-menu-open.png
<run-id>-03-menu-scrolled.png
```

## Checkpoints

- `authMe`: test token reaches the local API.
- `fixtureReady`: enough channels exist for overflow behavior.
- `menuOpened`: opening the active channel menu changes the screenshot.
- `menuHeightBounded`: popup height is below the threshold.
- `menuScrollsInternally`: wheel scrolling changes pixels inside the popup.
- `noBrowserErrors`: no page errors or Flutter assertion messages were captured.

## Failure Reading

- `fixtureReady` fails: the API cannot create or load enough channels.
- `menuOpened` fails: the coordinate did not hit the channel dropdown or the app
  did not render the menu.
- `menuHeightBounded` fails: the popup is still too tall or the wrong changed
  region was measured.
- `menuScrollsInternally` fails: the list is not scrollable or there are not
  enough visible channel items.
