# Background
The chat message list currently shows the "Jump to latest" button when the user is only a short distance from the latest content, and tapping the button animates to the list max extent. With extra list bottom padding, this can feel too eager and can visually overshoot/rebound when far away.

# Goals
- Show the jump button only when the user is significantly far from the latest content.
- Update jump animation target so it lands directly at the intended latest-content position without rebound-like behavior.
- Keep or improve existing widget test coverage.

# Implementation Plan (phased)
1. Update `MessageList` scroll-distance logic:
   - Replace fixed reveal threshold with a dynamic threshold based on viewport height (2 screens).
   - Compute distance from current offset to the latest-content anchor (max extent minus reserved bottom padding).
2. Update jump action behavior:
   - Animate to the latest-content anchor offset instead of absolute max extent.
   - Use a duration scaled by distance to keep motion stable over long jumps.
3. Update tests:
   - Adjust jump-to-latest assertion to anchor offset behavior.
   - Add coverage that button stays hidden when far distance is below the 2-screen threshold.
4. Validate:
   - Run repository bootstrap and targeted Flutter widget tests.

# Acceptance Criteria
- Jump button appears only when distance to latest-content anchor exceeds two full viewport heights.
- Tapping jump button animates directly to the latest-content anchor position (not absolute bottom padding extent).
- Message list widget tests pass, including updated jump behavior checks.
