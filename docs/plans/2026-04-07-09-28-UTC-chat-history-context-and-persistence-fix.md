# Background
用户反馈了两个问题：
1. 多轮对话中，第二轮推理似乎没有带上前文（`1+3` 后再发 `+5` 未得到 `9`）。
2. 消息在刷新时可能出现“空气泡”并丢失 AI 最终回复，尤其在 AI 回复完成前刷新。

当前实现里，Agent 会在本地会话中维护上下文，但请求模型时只发送了“当前用户消息”；同时消息持久化采用 500ms 防抖，且会先落库一个空内容的流式 assistant 占位消息，导致刷新后看到空泡。

# Goals
1. 修复多轮对话上下文组装：模型请求应携带历史消息而非仅当前轮。
2. 修复刷新导致的消息持久化异常：
   - 关键消息（尤其用户消息）立即持久化，减少刷新窗口内丢失。
   - 避免将“空内容 + 流式中”的 assistant 占位消息持久化到历史。
3. 补充测试覆盖，防止回归。

# Implementation Plan (phased)
## Phase 1: 多轮上下文修复
- 在 `RealModelGateway` 中新增/扩展生成接口，支持传入完整历史消息。
- 在 `AgentSessionImpl` 中调用网关时传入 `ContextManager.messages`。
- 后端 `/api/llm/chat` 请求体改为完整 `messages`（包含 system + 历史 user/assistant）。

## Phase 2: 持久化时序修复
- 将聊天持久化分为：
  - 立即持久化（用于用户发送、流结束、错误、停止等关键时刻）。
  - 防抖持久化（用于流式增量内容更新）。
- 持久化前过滤“空内容且仍在 streaming 的 assistant 占位消息”。
- 在页面 `dispose` 时尝试触发一次立即持久化（best effort）。

## Phase 3: 测试与验证
- 为 `agent_core` 增加测试：验证 `sendMessage` 时网关拿到完整上下文。
- 为 `mobile_chat_app` 的 `ChatHistoryApiService` 增加测试：验证占位 assistant 消息过滤规则。
- 运行受影响测试套件。

# Acceptance Criteria
1. 在同一会话中发送 `1+3` 后再发送 `+5`，请求模型的 messages 中包含上一轮 user/assistant 历史。
2. 用户发送后立即刷新，不会出现仅有空内容 assistant 气泡的持久化记录。
3. 正常完成的 assistant 回复仍可持久化并在刷新后可见。
4. 新增测试全部通过（例如 `flutter test` 相关用例、`npm test` 相关用例）。
