# Problem

The Bricks OpenClaw plugin currently uses a fixed `DEFAULT_ACCOUNT_ID` for its single account slot. When the configured `BRICKS_PLATFORM_TOKEN` changes to a different Bricks user, OpenClaw still sees the same account id, so its internal per-account routing/session scoping can overlap across users.

# Proposed approach

- Keep the plugin's flat channel config model as-is.
- Derive the OpenClaw `accountId` from the configured platform token's `userId` claim.
- If the stored `BRICKS_PLUGIN_ID` / `BRICKS_PLATFORM_TOKEN` cannot produce a valid user-scoped identity, surface an explicit error instead of silently falling back to `DEFAULT_ACCOUNT_ID`.
- Do not change the plugin state file layout in this step.

# Notes

- This fixes OpenClaw's account-slot scoping only; it does not yet isolate the plugin's own persisted state file.
- Validation for this step is limited to the plugin package checks and local `openclaw status`.
