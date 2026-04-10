# Architecture

## Overview

Bricks is composed of:

1. **React Web Frontend** (`apps/web_chat_app`)
   - Handles login entry, chat UI, and sidebar navigation.
   - Calls backend APIs via `/api/*`.
2. **Node Backend** (`apps/node_backend`)
   - Handles GitHub OAuth, auth session checks, chat orchestration, and model config APIs.

## Frontend Entry

- App bootstrap: `apps/web_chat_app/src/main.tsx`
- Main shell and routes: `apps/web_chat_app/src/App.tsx`
- Chat interaction page: `apps/web_chat_app/src/pages/ChatPage.tsx`

## Backend Entry

- API app composition: `apps/node_backend/src/app.ts`
- Auth routes: `apps/node_backend/src/routes/auth.ts`
- Chat routes: `apps/node_backend/src/routes/chat.ts`
- Config routes: `apps/node_backend/src/routes/config.ts`

## Runtime Flow (simplified)

1. User opens frontend and triggers GitHub OAuth from the login page.
2. Frontend checks `/api/auth/me` to determine authenticated state.
3. Authenticated users enter the app shell and navigate via sidebar.
4. Chat send action posts to `/api/chat/respond`; backend persists and returns assistant response.
