---
title: System Overview
sidebar_position: 1
---

# System Overview

Bricks uses a modular architecture with clear package boundaries between UI, contracts, runtime, and platform integration.

## Core principles (current)

- Agent threads are the primary unit of work.
- `agent_core` is kept separate from the UI package.
- Workspaces map to local filesystem directories.
- External agent platforms are integrated through plugin contracts.

## Package graph summary

- `apps/mobile_chat_app`
  - depends on `agent_core`, `agent_sdk_contract`, `workspace_fs`, `project_system`, `chat_domain`, `platform_bridge`, `design_system`
  - UI integration is kept separate from core runtime concerns and primarily relies on `agent_sdk_contract` interfaces
- `packages/agent_core`
  - depends on `agent_sdk_contract`
- `packages/test_harness`
  - supports fixtures and integration-style validation

## Event flow summary

User send action in chat UI -> contract session send -> runtime processing -> event stream -> UI render updates.

## Full architecture reference

See [`docs/architecture.md`](../architecture.md) for the complete architecture document.
