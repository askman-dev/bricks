# Background
The previous iteration exposed a local tooling gap: workspace guidance and verification used a scoped `melos run ... --scope=...` pattern that is not supported by the installed Melos CLI behavior in this environment. This made reproducible local verification harder.

# Goals
- Remove local verification friction caused by Melos command mismatch.
- Make init/bootstrap flow provide a reliable `melos` command in common shell paths.
- Document and verify the supported scoped test workflow.

# Implementation Plan (phased)
1. Update `tools/init_dev_env.sh` to create/update a `melos` shim in `~/.local/bin` (same pattern as `flutter`/`dart`).
2. Update script output to show the supported scoped test command (`melos exec --scope=<pkg> -- <cmd>`).
3. Run initialization and verify:
   - `melos` is invokable in-session after init.
   - scoped package tests succeed via supported Melos syntax.

# Acceptance Criteria
- Running `./tools/init_dev_env.sh` leaves a working `melos` command accessible via standard shim path setup in the current shell.
- The script’s completion instructions include a valid scoped test invocation pattern.
- Scoped `agent_core` tests pass using the documented command.
