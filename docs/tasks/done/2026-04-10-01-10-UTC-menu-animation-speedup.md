# Background
The chat UI currently uses default Flutter popup menu transition settings, which feel slow and start from a full collapsed translation impression. The requested UX is a globally faster menu animation with an iOS-like feel: quick reveal from approximately 80% scale with low starting opacity.

# Goals
- Speed up popup menu open/close animations in the chat screen and composer bar.
- Use a scale+fade transition profile that starts near 80% size and low opacity, avoiding a "from zero" feel.
- Keep the animation token centralized in the design system so it can be reused across any `PopupMenuButton`.

# Implementation Plan (phased)
1. Locate global app theme construction and popup menu usage points.
2. Add a shared `AnimationStyle` token (`menuPopupAnimationStyle`) in `BricksTheme` to reduce duration by ~50% and adjust curves for snappy response.
3. Apply `BricksTheme.menuPopupAnimationStyle` directly on each `PopupMenuButton` via its `popUpAnimationStyle` parameter. Note: `PopupMenuThemeData` does not expose a `popUpAnimationStyle` field in the Flutter version used by this project, so the per-button approach is the correct mechanism.
4. Run environment bootstrap and targeted Flutter tests/analyze for the touched package.
5. Review code map files and update only if indexing/entry-path metadata needs to reflect this behavior change.

# Acceptance Criteria
- Popup menus in the app use a faster transition than before (approximately half duration).
- Popup menus animate with scale+fade (starting around 0.8 scale and low opacity) rather than appearing to start from 0.
- Existing composer popup menu widget tests continue to pass.
- Validation commands are documented and reproducible (`./tools/init_dev_env.sh`, `cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart`).
