# OpenClaw network retry hardening

## Problem

The Bricks OpenClaw plugin runner already survives ordinary tick failures, but
DNS/connectivity failures such as `TypeError: fetch failed` with
`getaddrinfo ENOTFOUND ...` are not currently classified as retryable. That
means the runner keeps looping, but it logs an error every poll interval and
does not enter the same bounded backoff path used for retryable platform HTTP
failures.

## Approach

- Keep the runner alive on transient network failures as it already does today.
- Treat pre-response fetch/network failures as retryable runner failures.
- Reuse the existing bounded backoff ladder so DNS/connectivity outages recover
  automatically once the network or DNS issue clears.
- Add regression coverage proving both the helper classification and the
  `runUntilAbort()` loop behavior.

## Validation

- `cd apps/node_openclaw_plugin && npm test`
- `cd apps/node_openclaw_plugin && npm run type-check`
- `cd apps/node_openclaw_plugin && npm run build`

## Notes

- This hardening is intentionally narrow: it does not change message dispatch
  semantics or state handling, only how the runner classifies and retries
  transport-level failures before an HTTP response exists.
