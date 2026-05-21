---
name: evidence-case-loop
description: Use when an agent needs a repeatable per-case workflow for stubborn or complex bugs where fixes must be proven with before/after evidence. Guides agents to create a case-specific evidence directory with AGENTS.md, run.sh, flow/checkpoint scripts, summary.json, and before/after evidence. For browser setup, screenshots, local test auth, API/DB evidence, and secret handling, pair with evidence-driven-browser-test-env instead of duplicating those instructions.
---

# Evidence Case Loop

This skill defines a repeatable per-case fix loop.

It helps agents turn one stubborn bug into a self-contained evidence harness,
capture baseline proof, make a fix, rerun the same path, and report before/after
evidence.

This skill does not decide when evidence is required. It only describes the
workflow once the agent is using a case-specific evidence loop.

## Dependency

For browser startup, local backend/frontend setup, test login, screenshots,
console/network capture, API/DB evidence, and secret handling, use the
`evidence-driven-browser-test-env` skill.

Do not duplicate those instructions here. This skill only defines the
case-level loop and file organization.

## Case Directory

Create a directory for the specific case:

```text
tools/evidence/<case_name>/
```

Use the repository's existing evidence location when it differs. The directory
should be self-contained for the case.

Recommended files:

```text
tools/evidence/<case_name>/
├── AGENTS.md
├── run.sh
├── flow.mjs
├── checkpoint.mjs
└── static_server.mjs        # optional only when no shared server exists
```

Use case-specific script names when they improve clarity:

```text
tools/evidence/channel_dropdown_height/
├── AGENTS.md
├── run.sh
├── channel_dropdown_flow.mjs
└── channel_dropdown_checkpoint.mjs
```

## AGENTS.md

`AGENTS.md` is the case contract for future agents.

It should include:

- user-visible bug or requirement
- baseline behavior that must be proven before fixing
- fixed behavior that must be proven after fixing
- required fixture/data shape
- required environment variables
- run command
- evidence output location
- checkpoint list
- failure-reading notes

Keep it concrete. It should let the next agent rerun this exact case without
rediscovering the scenario from conversation history.

## run.sh

`run.sh` is the only entrypoint.

It should orchestrate the case without hiding the important artifacts:

- create a sortable run id
- create the evidence output directory
- load local environment when appropriate
- validate required variables
- prepare dependencies
- start or verify required services
- run the flow/checkpoint scripts
- print the final evidence directory
- print or point to `summary.json`

## Flow And Checkpoints

The flow script drives the exact user path. The checkpoint script, or checkpoint
helpers inside the flow, separates failure causes into named checks.

Prefer named checks such as:

```text
authMe
fixtureReady
baselineBugVisible
interactionReceived
apiStateMatches
dbStateMatches
fixedBehaviorVisible
noConsoleOrNetworkRegression
```

Each checkpoint should answer one question. Avoid a single vague `test passed`
result.

## Loop

1. Create or update the case directory.
2. Write `AGENTS.md` before implementation changes.
3. Write `run.sh` as the only entrypoint.
4. Write flow/checkpoint scripts for the exact user path.
5. Run baseline and capture evidence.
6. If baseline does not reproduce the bug, stop and report.
7. Fix implementation.
8. Rerun the same harness.
9. Compare before/after evidence.
10. Report evidence paths and remaining risks.

## Output Convention

Evidence should be written under:

```text
.cache/evidence/<case_name>/<run-id>/
```

Each run should write:

```text
summary.json
<run-id>-*.png
<run-id>-*.log
browser-events.json
```

`summary.json` should include:

- run id
- case name
- relevant local URLs
- evidence directory
- named checkpoint results
- diagnosis
- important file paths
- failure details when a checkpoint fails

## Rule

Do not claim the bug is fixed unless the same case harness that reproduced the
baseline failure also passes after the fix.

If the baseline cannot reproduce the bug, stop and report the evidence gap
instead of guessing a fix.

## Final Report

When the loop is complete, report:

- baseline evidence path
- fixed evidence path
- changed files
- validations run
- environment limitations
- whether local services are still running
