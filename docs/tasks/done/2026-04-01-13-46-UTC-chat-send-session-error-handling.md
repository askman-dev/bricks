# Background
After deploying the prior fix, the user still reports that sending messages yields no response. This indicates session initialization or stream start failures may still be uncaught, leaving the UI without assistant output.

# Goals
- Ensure chat send flow handles session creation/start errors and surfaces them to the user.
- Prevent the UI from getting stuck in sending/streaming state when async setup fails.
- Keep the behavior observable with clear error text in the assistant message bubble.

# Implementation Plan (phased)
1. Inspect `_sendMessage` asynchronous flow for unhandled errors in `_sessionForAgent(...).then(...)`.
2. Add explicit error handling (`catchError`) to convert setup failures into assistant-visible error content.
3. Reset `_isSending`/`_isStreaming` flags in that failure path.
4. Run `flutter analyze apps/mobile_chat_app` and `cd apps/mobile_chat_app && flutter test`.

# Acceptance Criteria
- If session creation/start fails before stream subscription, the assistant placeholder shows `Error: ...`.
- The composer is re-enabled because `_isSending` and `_isStreaming` are reset.
- Static analysis and package tests pass for the touched app package.
