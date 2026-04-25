# Architecture

## Overview

Bricks is a **native agent console** powered by an **Agent Core** module. Users connect to external agent platforms (such as OpenClaw), run multiple agent threads in parallel, and keep every run visible and controllable from a single workspace.

---

## Core Principles

### 1. Agent threads are the primary unit of work
The console is organized around agent threads. Each thread represents an active or completed agent task. Users can start, switch between, inspect, stop, retry, or recover threads independently.

### 2. Agent Core is a separate module
`agent_core` is an independently testable module. The console depends on stable `agent_sdk_contract` interfaces, not on `agent_core` internals.

### 3. Multi-thread, multi-partition architecture
One workspace can host multiple agent threads running in parallel. Each thread is partitioned by context boundary (task/agent/environment) to keep state, memory, and outputs isolated and auditable. The orchestration layer supports controlling multiple OpenClaw plugin instances so work can be routed by capability, environment, or workload.

### 4. Workspace maps to the device filesystem
The app is local-first. Each workspace is a directory on the user's device. The default workspace is created automatically.

### 5. Agent platforms are external, not built-in
Bricks connects to agent platforms via plugin interfaces rather than embedding a single built-in agent. This keeps the console decoupled from any specific agent runtime.

---

## Package Dependency Graph

```
mobile_chat_app
  ├── agent_sdk_contract   (session, events, tool contracts)
  ├── workspace_fs         (workspace, thread, resource management)
  ├── project_system       (agent task/project abstraction)
  ├── chat_domain          (thread, message models)
  ├── platform_bridge      (filesystem, WebView, local server)
  └── design_system        (shared UI)

agent_core
  └── agent_sdk_contract   (implements the contracts)

test_harness
  ├── agent_sdk_contract
  ├── workspace_fs
  └── project_system
```

---

## Package Descriptions

### `agent_sdk_contract`
Stable interface layer. Defines `AgentClient`, `AgentSession`, event stream types, tool call schemas, sub-agent schemas, skill manifests, and settings contracts. The console depends exclusively on this package, never on `agent_core` internals.

### `agent_core`
Intelligence runtime. Owns the agent run loop, context loading/trimming/persistence, tool execution engine, sub-agent registry, skills loading, permissions enforcement, settings merging, event streaming, and provider abstraction.

### `workspace_fs`
Maps the local filesystem to app concepts: workspace discovery and creation, thread directories, resource directories, thread/conversation persistence, and app config loading.

### `project_system`
Defines what an agent task or project is: schema, file layout, creation, preview/run support, agent bridge, and snapshots. Does **not** contain domain-specific runtimes.

### `chat_domain`
Pure domain models: `Thread`, `Message`, `MessageRole`, input composer state, and attachment models. No Flutter/UI dependencies.

### `platform_bridge`
Cross-platform concerns: filesystem permissions, sandbox paths, local HTTP server for project preview, WebView/browser runtime integration, device differences across iOS/Android/desktop/web.

### `design_system`
Shared design tokens (colors, typography, spacing), theme, and reusable UI widgets for the agent console.

### `test_harness`
Test support: fake `AgentClient`, fake filesystem, sample workspaces, sample projects, sample resources, and e2e fixture helpers.

---

## Event Flow

```
User sends message in a thread
  → ThreadComposer (mobile_chat_app)
  → AgentSession.sendMessage() (agent_sdk_contract)
  → AgentCore run loop (agent_core)
      → context load
      → provider call (streaming)
      → tool calls (workspace_fs, project_system, platform_bridge)
      → event stream → AgentSessionEvent
  → ThreadMessageList re-renders (mobile_chat_app)
```

---

## Workspace Filesystem Layout

```
~/bricks/                         # root bricks directory
├─ workspaces/
│  ├─ default/                    # default workspace
│  │  ├─ .bricks/
│  │  │  ├─ workspace.yaml        # workspace metadata
│  │  │  └─ config.yaml           # workspace-level config overrides
│  │  ├─ conversations/
│  │  │  └─ <id>.json
│  │  ├─ projects/
│  │  │  └─ <project-name>/
│  │  │     ├─ bricks.project.yaml
│  │  │     └─ ...project files
│  │  └─ resources/
│  │     └─ ...attached resources
│  └─ <other-workspace>/
└─ config.yaml                    # global app config
```
