# Responsive Sidebar Surface

## Background
The chat navigation drawer currently expands to the full viewport width and relies on implicit Material/Scaffold background behavior. The desired dark-mode behavior is a black navigation surface on both compact and wide layouts, with compact retaining full-width navigation and wide layouts using a fixed sidebar width so it contrasts with the near-black chat canvas.

## Goals
- Make the chat navigation drawer background explicit.
- Use black/chrome background for the dark sidebar in compact and wide layouts.
- Keep compact drawer full-width.
- Use a fixed wide-layout drawer width aligned with the ChatGPT-like 260px reference.

## Implementation Plan (phased)
1. Add responsive drawer width and background role selection in `ChatScreen`.
2. Apply the drawer background to both `Drawer` and the nested navigation content theme so the inner `Scaffold` cannot paint a different surface.
3. Update code maps to capture the sidebar width/surface smoke check.
4. Run formatting, focused navigation tests, Flutter analysis, and code-map YAML validation.

## Acceptance Criteria
- In dark compact chat, the sidebar drawer is full-width and black.
- In dark wide chat, the sidebar drawer is fixed-width and black.
- In dark wide chat, opening the sidebar creates visible contrast against the `#212121` chat background.
- No new color token is introduced.
- Validation commands pass.
