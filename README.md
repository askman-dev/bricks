# Bricks

A **chat-first creation app** powered by an Agent Core module.

Users interact through conversation to create, modify, and iterate on website/app projects stored locally on their device.

---

## Monorepo Structure

```text
bricks/
├─ apps/
│  └─ mobile_chat_app/        # Flutter host application
│
├─ packages/
│  ├─ agent_core/              # Intelligence runtime (session loop, tools, sub-agents)
│  ├─ agent_sdk_contract/      # Stable interface layer for consumers
│  ├─ workspace_fs/            # Filesystem mapping (workspaces, projects, resources)
│  ├─ project_system/          # Website/app project abstraction
│  ├─ chat_domain/             # Chat domain models (conversations, messages)
│  ├─ platform_bridge/         # Cross-platform bridge (filesystem, WebView, sandbox)
│  ├─ design_system/           # Shared design tokens and widgets
│  └─ test_harness/            # Test support (fakes, fixtures, helpers)
│
├─ config/                     # Default configuration files
├─ fixtures/                   # Sample workspaces, projects, and resources
├─ docs/                       # Architecture and developer documentation
├─ tools/                      # Developer tooling scripts
└─ melos.yaml                  # Monorepo management
```

---

## Packages

| Package | Description |
|---|---|
| [`agent_core`](packages/agent_core/) | Agent run loop, context management, tool execution, sub-agent registry, skills, permissions, provider abstraction, event streaming |
| [`agent_sdk_contract`](packages/agent_sdk_contract/) | Stable interface contracts: agent client, session, event stream, tool/sub-agent/skill schemas |
| [`workspace_fs`](packages/workspace_fs/) | Workspace discovery/creation, project & resource directories, conversations persistence, app config |
| [`project_system`](packages/project_system/) | Website/app project schema, file layout, preview/run support, AI bridge, snapshots |
| [`chat_domain`](packages/chat_domain/) | Conversation and message models, input composer, attachments |
| [`platform_bridge`](packages/platform_bridge/) | Filesystem permissions, sandbox paths, local server, WebView/browser integration |
| [`design_system`](packages/design_system/) | Shared UI tokens, theme, and reusable widgets |
| [`test_harness`](packages/test_harness/) | Fake providers, fake filesystem, sample workspaces/projects, e2e fixtures |

---

## Getting Started

### Quick Setup

Initialize your development environment with one command:

```bash
./tools/init_dev_env.sh
```

This will:
- Check prerequisites (Flutter, Dart, Melos)
- Set up Flutter web support
- Bootstrap all package dependencies
- Show next steps

Or follow the manual steps below:

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.x
- [Melos](https://melos.invertase.dev/) (`dart pub global activate melos`)
- [Node.js](https://nodejs.org/) ≥ 20.19.0 (for OpenSpec CLI)

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

### Bootstrap

```bash
melos bootstrap
```

### Run the app

```bash
cd apps/mobile_chat_app
flutter run
```

### Run all tests

```bash
melos test
```

Or run tests for specific package types:

```bash
# Run tests for Dart-only packages
melos test:dart

# Run tests for Flutter packages
melos test:flutter
```

### Analyze

```bash
melos analyze
```

### Build

For comprehensive build instructions, see [BUILD.md](BUILD.md).

Quick build using the automated script:

```bash
./build.sh
```

---

## Architecture

See [`docs/architecture.md`](docs/architecture.md) for the full architecture design.

### Core principles

1. **Chat is the main interaction model** – the app is centered around conversation.
2. **Agent Core is a separate module** – the chat app depends on stable `agent_sdk_contract` interfaces, not on `agent_core` internals.
3. **No plugin system** – skills, sub-agents, and filesystem-based configuration are sufficient.
4. **Workspace maps directly to the device filesystem** – the app is local-first.
5. **Projects are websites/apps** – domain-specific runtimes are content/templates, not architecture.
