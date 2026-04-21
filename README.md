# Bricks

A **chat-first creation app** powered by an Agent Core module.

Users interact through conversation to create, modify, and iterate on website/app projects stored locally on their device.

---

## Architecture Overview

```text
+----------------------+      +-------------------------------+
|      Workspace       | ---> |      Channel Router Layer     |
+----------------------+      +-------------------------------+
                                         |
                                         v
                 +-----------------------+-----------------------+
                 |                       |                       |
                 v                       v                       v
        +----------------+      +----------------+      +----------------+
        | Channel: Plan  |      | Channel: Build |      | Channel: QA/Ops|
        +----------------+      +----------------+      +----------------+
                 |                       |                       |
                 v                       v                       v
      +--------------------+   +--------------------+   +--------------------+
      | Partition: Scope   |   | Partition: Backend |   | Partition: Validate|
      +--------------------+   +--------------------+   +--------------------+
                 |                       |                       |
                 v                       v                       v
   +---------------------------+ +---------------------------+ +---------------------------+
   | OpenClaw Plugin Node P-1  | | OpenClaw Plugin Node B-1  | | OpenClaw Plugin Node Q-1  |
   +---------------------------+ +---------------------------+ +---------------------------+
                 |                       |                       |
                 +-----------------------+-----------------------+
                                         |
                                         v
                        +-----------------------------------+
                        | Multi-Instance OpenClaw Controller|
                        +-----------------------------------+
```

## Packages

| Package | Description |
|---|---|
| [`agent_core`](packages/agent_core/) | Agent runtime loop, context/session orchestration, tool dispatch, skills, provider abstraction, and event streaming |
| [`agent_sdk_contract`](packages/agent_sdk_contract/) | Stable SDK contracts between app-facing clients and the agent runtime |
| [`bricks_ai_core`](packages/bricks_ai_core/) | Bricks AI integration layer and shared AI-facing runtime capabilities |
| [`bricks_ai_smoke_test`](packages/bricks_ai_smoke_test/) | Smoke-test harness for validating AI integration flows end-to-end |
| [`workspace_fs`](packages/workspace_fs/) | Local workspace/project/resource filesystem mapping and persistence |
| [`project_system`](packages/project_system/) | Project model, file layout conventions, preview/run integration, snapshots |
| [`chat_domain`](packages/chat_domain/) | Conversation domain models, message flow structures, and chat state abstractions |
| [`platform_bridge`](packages/platform_bridge/) | Platform bridge for filesystem permissions, sandbox paths, local services, and browser/WebView integration |
| [`design_system`](packages/design_system/) | Shared UI tokens, themes, and reusable components |
| [`test_harness`](packages/test_harness/) | Test doubles, fixtures, and workspace/project test utilities |

---

## Getting Started

### Quick Setup

Initialize your development environment:

```bash
./tools/init_dev_env.sh
```

### OpenSpec

This repository is initialized for OpenSpec with checked-in tool integrations for GitHub Copilot, Codex, and Claude Code, plus project config under `openspec/`.

Committed OpenSpec artifacts in this repository include:

- `.github/` for GitHub Copilot prompts and skills
- `.codex/` for Codex skills
- `.claude/` for Claude Code commands and skills

You do not need to install OpenSpec just to use these checked-in integrations in this repository.

Install the CLI locally only if you want to refresh the setup or use the terminal workflow:

```bash
npm install -g @fission-ai/openspec@latest
openspec init --tools github-copilot,codex,claude
```

Then start a spec-driven change by creating a new OpenSpec proposal with:

```text
/opsx:propose "your idea"
```

### Build / Test / Analyze

For build prerequisites and detailed command workflows, see [BUILD.md](BUILD.md).

For quick automation, use:

```bash
./build.sh
```

---

## Architecture

See [`docs/architecture.md`](docs/architecture.md) for the full architecture design.

### Product architecture highlights

1. **Multi-channel conversation architecture** – one workspace can host multiple channels (for example: product planning, implementation, QA, and operations).
2. **Multi-partition dialogue system** – each channel can be partitioned by context boundary (task/thread/environment) to keep prompts, memory, and outputs isolated and auditable.
3. **Multi-OpenClaw instance control** – the orchestration layer supports controlling multiple OpenClaw instances so teams can route work by capability, environment, or workload.
4. **Agent Core is a separate module** – the chat app depends on stable `agent_sdk_contract` interfaces, not on `agent_core` internals.
5. **Workspace maps directly to the device filesystem** – the app is local-first and keeps project artifacts transparent.
