# Bricks

Bricks is a chat-first app with a **React frontend** and a Node.js backend.

## Monorepo Structure

```text
bricks/
├─ apps/
│  ├─ web_chat_app/      # React + Vite frontend
│  └─ node_backend/      # Express API backend
├─ docs/
├─ config/
├─ tests/
└─ tools/
```

## Quick Start

```bash
./tools/init_dev_env.sh
npm --prefix apps/node_backend run dev
npm --prefix apps/web_chat_app run dev
```

## Validation

```bash
npm --prefix apps/web_chat_app run test
npm --prefix apps/web_chat_app run build
npm --prefix apps/node_backend run test
```
