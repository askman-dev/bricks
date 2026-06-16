# Background
当前刷新后聊天历史丢失问题，上一版通过前端 `SharedPreferences` 持久化修复，但这不满足“后端数据库持久化 + 跨平台加载”的要求。并且频道支持多 Agent 接话，历史必须由服务端统一存储，避免端侧隔离导致上下文不一致。

# Goals
- 移除前端本地聊天历史持久化实现。
- 新增后端数据库会话历史持久化接口（按用户 + 会话 scope）。
- 聊天页改为从后端加载/保存历史，刷新后可恢复并继续聊天。
- 保留多 Agent 消息链路（用户消息 + 多 assistant 消息）完整存储。

# Implementation Plan (phased)
1. 在 `apps/node_backend` 新增 DB migration 建立 `chat_sessions`（user_id + session_id 唯一，messages JSON，checkpoint cursor，channel/thread metadata）。
2. 新增 `chatHistoryService` 读写服务与 `routes/chat.ts`，提供鉴权后的 `GET /api/chat/history/:sessionId` 与 `PUT /api/chat/history/:sessionId`。
3. 在 `app.ts` 注册 `/api/chat` 路由。
4. 在移动端新增 `ChatHistoryApiService`，通过后端 API 读写历史；删除 `ChatHistoryStore`（shared_preferences）及其测试。
5. 更新 `ChatScreen`：初始化/切换 scope 时从后端加载；消息变更后上传快照。
6. 增加后端路由单测与前端 API 服务单测，验证跨平台依赖后端存储。

# Acceptance Criteria
- 聊天消息（用户 + 多 Agent 回复）会保存到后端数据库。
- 刷新页面后可恢复历史并继续聊天，且不依赖前端本地缓存。
- 同一账号在不同平台登录后，可加载同一 session scope 的历史。
- `apps/node_backend` 与 `apps/mobile_chat_app` 相关测试通过。
