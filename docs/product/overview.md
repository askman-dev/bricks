# Product Overview

Bricks is an agent console centered on multi-thread task execution and control.

## What Bricks does today

- Connects to external agent platforms through plugin integration points.
- Runs multiple task threads in one workspace.
- Exposes run state and recovery controls for agent threads.
- Supports route-aware conversation handling across default and OpenClaw paths.

## Core product areas in this repository

- `apps/mobile_chat_app`: user-facing console for auth, chat session, model and node settings.
- `apps/node_backend`: API service for auth, chat, model config, and platform endpoints.
- `apps/node_openclaw_plugin`: pull-only OpenClaw plugin runtime for platform events and writeback.

## Primary user value

- Keep many agent tasks visible instead of collapsing all work into one linear chat stream.
- Control task lifecycle (start/switch/inspect/recover) with explicit state.
- Connect existing agent runtime ecosystems instead of replacing them.
