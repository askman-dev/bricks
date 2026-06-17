# Local Manual AI Test Environment Docs

## Background

The local manual test setup proved useful for validating realistic chat behavior
without deploying: the browser runs a local Flutter Web build, the API is local,
the database is cloud Turso, auth uses the fixture test token, and the fixture
user can have a real Gemini configuration created through the local backend.

## Goals

- Document the reusable manual test setup for local API plus local Flutter Web
  plus cloud Turso.
- Explain how to provide an AI provider token without pasting it into chat.
- Explain the encryption boundary for fixture-user LLM configs written through
  the local backend.
- Update the evidence-driven browser-test skill so future agents reuse this
  pattern.

## Implementation Plan

1. Add a `docs/testing/` guide for launching the local manual AI test
   environment.
2. Include environment variables, LLM config creation, startup commands,
   verification probes, and shutdown commands.
3. Update the evidence skill with a manual cloud-DB test mode and token-handling
   guidance.
4. Update code maps so future agents can discover the guide.

## Acceptance Criteria

- A developer can start the local backend and Flutter Web app from the guide.
- The guide keeps provider tokens in `.env.local` and never asks for them in
  conversation.
- The guide explains why fixture-user configs may not be visible to a real
  production user.
- The guide explains how `ENCRYPTION_KEY` affects local reads of LLM configs
  written to cloud Turso.

## Validation Commands

- `npx js-yaml docs/code_maps/feature_map.yaml >/dev/null`
- `npx js-yaml docs/code_maps/logic_map.yaml >/dev/null`
