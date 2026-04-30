# Background
The chat screen AppBar currently uses the title dropdown to switch sub-sections and uses a right-side three-dot menu for section management. Product now needs the title dropdown to switch channels, and section switching/management should move into a dedicated AppBar menu near the title.

# Goals
- Make the AppBar title dropdown switch channels.
- Add a section menu in the AppBar that is left-aligned near the channel title.
- Convert the previous three-dot control into a section-name dropdown with grouped menu content.
- Keep section list synchronized with the active channel after channel switching.

# Implementation Plan (phased)
1. Update the title PopupMenuButton to list channels and call `_switchChannel`.
2. Replace the right-side three-dot actions menu with an inline section dropdown button rendered next to the channel title.
3. Build section dropdown groups in this order: action items (new sub-section, rename placeholder, archive placeholder), divider, section navigation list.
4. Ensure displayed section label and menu list resolve from `_activeSubSection` and `_activeSubSections` so they refresh naturally after `_switchChannel`.

# Acceptance Criteria
- Clicking AppBar channel title opens a channel list and selecting one switches active channel.
- A new section dropdown appears near the channel title (not on the right edge).
- Section dropdown shows a function group first, then a divider, then the section list group.
- Existing placeholder actions for section rename/archive remain non-functional and show the existing "功能暂未实现" feedback.
- When channel changes, section label and section list reflect the target channel.
