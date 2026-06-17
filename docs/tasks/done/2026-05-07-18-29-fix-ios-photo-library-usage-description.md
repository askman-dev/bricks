# Background
Apple rejected iOS build 1 (version 0.1.0) for missing `NSPhotoLibraryUsageDescription` in the Runner app Info.plist.

# Goals
- Add the required privacy usage string so App Store validation passes ITMS-90683.
- Keep the change minimal and user-facing text clear.

# Implementation Plan (phased)
1. Inspect iOS Runner Info.plist for existing privacy keys.
2. Add `NSPhotoLibraryUsageDescription` with a clear purpose string.
3. Run a lightweight repo check (git diff) to verify only intended files changed.

# Acceptance Criteria
- `apps/mobile_chat_app/ios/Runner/Info.plist` contains `NSPhotoLibraryUsageDescription` with a non-empty, user-facing explanation.
- Diff contains only the intended privacy key addition and task plan documentation.
