# Architecture

## Overview

Bricks is a **chat-first creation app** powered by an **Agent Core** module. The primary user output is a **website/app project** stored in a local workspace on the user's device.

---

## Core Principles

### 1. Chat is the main interaction model
The app is centered around conversation. Users primarily interact through chat to create websites, modify projects, attach local resources, and preview iterations.

### 2. Agent Core is a separate module
`agent_core` is an independently testable module. The chat app depends on stable `agent_sdk_contract` interfaces, not on `agent_core` internals.

### 3. Multi-channel, multi-partition conversation architecture
One workspace can host multiple channels (for example: product planning, implementation, QA). Each channel can be further partitioned by context boundary to keep prompts, memory, and outputs isolated. The orchestration layer supports controlling multiple OpenClaw plugin instances so teams can route work by capability, environment, or workload.

### 4. Workspace maps to the device filesystem
The app is local-first. Each workspace is a directory on the user's device. The default workspace is created automatically.

### 5. Projects are websites/apps
The architecture only concerns itself with website/app projects. Domain-specific runtimes (bridges, circuits, etc.) are content themes, not architectural modules.

---

## Package Dependency Graph

```
mobile_chat_app
  ├── agent_sdk_contract   (session, events, tool contracts)
  ├── workspace_fs         (workspace, project, resource management)
  ├── project_system       (website/app project abstraction)
  ├── chat_domain          (conversation, message models)
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
Stable interface layer. Defines `AgentClient`, `AgentSession`, event stream types, tool call schemas, sub-agent schemas, skill manifests, and settings contracts. The chat app depends exclusively on this package, never on `agent_core` internals.

### `agent_core`
Intelligence runtime. Owns the agent run loop, context loading/trimming/persistence, tool execution engine, sub-agent registry, skills loading, permissions enforcement, settings merging, event streaming, and provider abstraction.

### `workspace_fs`
Maps the local filesystem to app concepts: workspace discovery and creation, project directories, resource directories, conversations persistence, and app config loading.

### `project_system`
Defines what a project is: schema, file layout, creation, preview/run support, website AI bridge, and snapshots. Does **not** contain domain-specific runtimes.

### `chat_domain`
Pure domain models: `Conversation`, `Message`, `MessageRole`, input composer state, and attachment models. No Flutter/UI dependencies.

### `platform_bridge`
Cross-platform concerns: filesystem permissions, sandbox paths, local HTTP server for project preview, WebView/browser runtime integration, device differences across iOS/Android/desktop/web.

### `design_system`
Shared design tokens (colors, typography, spacing), theme, and reusable UI widgets for the chat app.

### `test_harness`
Test support: fake `AgentClient`, fake filesystem, sample workspaces, sample projects, sample resources, and e2e fixture helpers.

---

## Event Flow

```
User types message
  → ChatComposer (mobile_chat_app)
  → AgentSession.sendMessage() (agent_sdk_contract)
  → AgentCore run loop (agent_core)
      → context load
      → provider call (streaming)
      → tool calls (workspace_fs, project_system, platform_bridge)
      → event stream → AgentSessionEvent
  → ChatMessageList re-renders (mobile_chat_app)
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
