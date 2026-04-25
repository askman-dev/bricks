# Bricks

**The agent console for tinkerers.**

Run agents side by side. Keep every thread in sight.

Bricks is a native console for working with agent platforms like OpenClaw. It lets you connect agents, run them in parallel, switch between task threads, and keep every run visible and controllable.

Traditional chat tools are built for messages. Bricks is built for agents.

---

## Why Bricks?

Most agent systems are powerful, but their interfaces are limited.

When agents are connected to Telegram, Discord, or team chat tools, everything becomes a linear message stream. That works for simple Q&A, but breaks down when you want to run multiple agents, switch between tasks, inspect progress, recover from failures, or keep long-running work under control.

Bricks is built for that gap.

- It is not another code-generation workspace.
- It is not a chat wrapper.
- It is a console for people who actively work with agents.

## What Bricks helps you do

**Connect agent platforms.**
Add OpenClaw or other agent platforms and make their agents available inside one native workspace.

**Run agents side by side.**
Start multiple agent threads, keep them visible, and switch between them without losing context.

**Stay in control.**
See which agents are running, waiting, completed, or failed. Stop, retry, continue, or inspect a thread when needed.

**Use richer agent interfaces.**
Agents should not be limited to plain text replies. Bricks is designed to support richer cards, controls, task views, and generative UI surfaces over time.

## Who Bricks is for

Bricks is for people who like to explore, combine, and control agent systems:

- developers building with agent platforms
- AI product builders testing agent workflows
- tinkerers who run many agents at once
- teams experimenting with OpenClaw-style agent systems

If you only need a simple chatbot, Bricks may be more than you need.
If you want to work with many agents without losing the thread, Bricks is for you.

## Product direction

Bricks focuses on three things:

**Agent platforms** — Connect to external agent systems instead of locking users into one built-in agent.

**Many threads** — Treat each agent task as a visible, recoverable thread rather than burying everything in one chat stream.

**Control** — Make agent work observable and interruptible: state, progress, errors, retries, and handoffs should be clear.

## Current status

Bricks is in early development.

The first goal is to make OpenClaw-style agent platforms feel usable inside a native agent console:

- connect an agent platform
- discover available agents
- start agent threads
- view running state
- switch between tasks
- control or recover failed runs

## What Bricks is not

Bricks is not trying to be GitHub Spark, v0, Bolt, or a general code-generation agent.

Bricks may support generated interfaces and small app-like surfaces in the future, but its core purpose is different: Bricks is the console layer for agent platforms.

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

1. **Multi-thread agent console** – one workspace hosts multiple agent threads running in parallel, each visible and independently controllable.
2. **Agent platform integration** – Bricks connects to external agent platforms (such as OpenClaw) via plugin interfaces rather than embedding a single built-in agent.
3. **Multi-partition thread system** – each thread is partitioned by context boundary (task/agent/environment) to keep state, memory, and outputs isolated and auditable.
4. **Multi-OpenClaw instance control** – the orchestration layer supports controlling multiple OpenClaw instances so work can be routed by capability, environment, or workload.
5. **Agent Core is a separate module** – the console depends on stable `agent_sdk_contract` interfaces, not on `agent_core` internals.
