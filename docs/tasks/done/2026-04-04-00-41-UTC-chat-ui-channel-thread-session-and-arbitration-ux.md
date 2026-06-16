# Chat UI Channel/Thread/Session + Arbitration UX Plan

## Background
The chat surface needs to expose channel and sub-thread context in the UI while preserving the existing component structure and minimizing implementation cost. The sidebar navigation should support channel management and the top app bar should support sub-section switching. In parallel, the UI should surface asynchronous task lifecycle and arbitration/direct routing context aligned with the existing architecture plans.

## Goals
1. Adjust sidebar behavior to full-width drawer and place settings/sessions/new-channel controls on the navigation header row.
2. Show channel list under "Manage Agents" with a default channel and in-list create-channel affordance.
3. Add top-right sub-section selector with "新建子区" and "主区" fixed entries plus user-created entries.
4. Surface channel/thread/session IDs and direct vs arbitration mode in the chat UI.
5. Expose task lifecycle status and routing metadata in message rendering.

## Implementation Plan (phased)
### Phase 1: Navigation and channel controls
- Expand drawer width to 100% viewport.
- Update `ChatNavigationPage` to include right-side action icons for settings/sessions/new channel.
- Add channel list model and selected channel rendering under "Manage Agents".
- Add "新建频道" button and timestamp-based naming when creating channels.

### Phase 2: Chat header and sub-section switching
- Add app bar action for sub-section dropdown.
- Include fixed entries (`新建子区`, `主区`) and dynamic user-created sub-sections per channel.
- Maintain active channel + sub-section state locally in chat screen state.

### Phase 3: Async/arbitration UX alignment
- Add context bar displaying channel/thread/session IDs and direct/arbitration mode.
- Extend chat message view model with task lifecycle fields and routing metadata.
- Render task status, IDs, fallback markers, and recovered-sync markers in message list.
- Add a lightweight reconnect-sync simulation action for UI verification.

## Acceptance Criteria
1. Sidebar opens as full-width drawer and shows settings/sessions/new-channel actions on the same row.
2. Channel list is visible under "Manage Agents", includes default channel, and supports timestamp channel creation.
3. App bar contains sub-section dropdown with required fixed options and dynamic user-created entries.
4. Message/task UI includes task state (`accepted`, `dispatched`, `completed`, `failed`, `cancelled`) and task IDs.
5. Context bar shows channel/thread/session and routing mode.
6. Existing chat navigation widget tests pass with updated API and channel list expectations.
