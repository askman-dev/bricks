---
name: evidence-driven-browser-test-env
description: Use when debugging or validating product behavior that cannot be trusted through unit tests alone because it depends on realistic data, diverse historical states, browser rendering, scroll/layout state, user interactions that trigger visible behavior, async updates, or screenshot evidence. Guides agents to build a local or CI-friendly data-backed test environment, isolate fixture data safely, bypass auth only in test mode, drive the real browser when needed, capture evidence, and document the setup for future reuse.
---

# Evidence-Driven Browser Test Environment

Use this skill when the bug or requirement is only credible after observing the
running product with realistic data and browser rendering.

## When To Use

Use this workflow when one or more are true:

- Unit tests can pass while the user-visible experience is still wrong.
- The behavior depends on rich data: history, empty states, large records,
  long text, tool/status rows, multiple users, or mixed old/new states.
- The behavior depends on browser layout, fonts, scrolling, viewport size,
  async loading, streaming, SSE, or network timing.
- The visible effect appears only after user interaction, such as click, type,
  send, scroll, long press, route switch, tab switch, drawer/menu open, or
  dialog submit.
- The user needs screenshot or video evidence, not just command output.

## Core Rule

Do not start by trusting existing tests. First define the user-observable
phenomenon, then identify the data states required to see it, then build the
smallest environment that renders those states through the real app.

## Environment Workflow

1. List every data state needed to reproduce or validate the behavior.
2. Decide whether production data helps. If it does, export only the minimum
   user/table subset needed for the task.
3. Prefer committed, reviewed, sanitized JSON fixtures for long-term reuse.
   Generate local SQLite/libSQL databases from those fixtures when the app
   needs a real DB.
4. Keep raw production exports, tokens, generated JWTs, local DB files, and
   screenshots under ignored local paths such as `.cache/`.
5. Run the normal backend against the fixture DB, not a mocked API, unless the
   user explicitly wants component-only validation.
6. Run the normal frontend against the local backend.
7. Bypass login only through explicit local/test mode. Do not weaken production
   auth code to make testing easier.
8. Use browser automation or manual browser actions to reach the target state.
9. Capture screenshots before and after the relevant state transition.
10. Write the setup method under `docs/testing/` when it should be reused.

## Interaction-Triggered Behavior

Use browser-driven validation when the visible result only appears after a user
action.

Examples:

- Clicking a button, menu, tab, drawer item, or dialog action.
- Typing into an input or composer.
- Sending a message or submitting a form.
- Scrolling to a specific position before acting.
- Switching channel, section, route, model, or workspace.
- Long-pressing, right-clicking, or opening a context menu.
- Waiting for streaming, SSE, polling, or network updates after an action.

Rules:

- Prefer real browser interaction over directly mutating app state.
- Verify the interaction was actually received by the app.
- For scroll-sensitive behavior, capture the pre-action viewport and the
  post-action viewport.
- For async behavior, wait for an observable condition instead of relying only
  on fixed sleeps.
- If browser automation cannot reliably drive the interaction, say so and build
  a narrower component-level harness using the real component. Label that
  evidence as component-level, not full browser evidence.
- Do not accept a screenshot that only proves the page rendered; it must show
  the state after the triggering action.

## Evidence Requirements

Collect enough evidence to prove both data and UI conditions:

- API/data evidence: record fixture counts, selected scope/session/user, and
  key role/type distribution.
- Browser evidence: screenshots for each user story or acceptance criterion.
- Interaction evidence: before/after screenshots for user-triggered behavior.
- Console/network evidence: record errors, font loading warnings, failed
  requests, or white-screen causes that could affect layout.
- Command evidence: record the validation commands and their pass/fail result.

## What To Commit

Commit reusable capability, not sensitive generated output:

- Fixture-building scripts.
- Sanitized JSON fixture definitions when they are meant to be reused.
- Local/CI setup documentation in `docs/testing/`.
- Test harnesses that generate evidence or assert critical layout behavior.
- `.gitignore` entries for generated DBs, screenshots, logs, and caches.

## What Not To Commit

Do not commit:

- Production tokens, API keys, auth tokens, JWTs, or remote DB URLs.
- Raw production DB exports.
- Local generated SQLite/libSQL files.
- Screenshot caches that contain real user data.
- Browser profiles or local storage dumps.

## Failure Checklist

Before trusting the result, check:

- Does the fixture actually contain the state required by the user story?
- Is the app loading the expected fixture DB/backend, not production or stale
  local state?
- Did the initial load fetch the expected amount of data?
- Did browser automation really trigger the intended click/type/scroll/send?
- Is the screenshot taken after the app finished rendering the target state?
- Are fonts available and stable enough that text layout is not changing after
  the screenshot?
- Are console and network errors understood?
- Are local auth bypasses limited to test mode?
- Are generated files ignored and sensitive values absent from Git?
