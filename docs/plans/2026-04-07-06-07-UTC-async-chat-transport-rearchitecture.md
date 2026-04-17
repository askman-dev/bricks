# Background
现有实现已经把历史放到后端，但仍是“整段会话快照覆盖”模型，不满足异步对话运输层要求（任务状态机、幂等提交、增量同步、断线恢复 replay）。这会在多 Agent 接话和多端并发写入时带来覆盖风险。

# Goals
- 设计并落地面向异步对话的后端权威传输层。
- 用任务（task）+ 消息日志（message log）替代会话快照覆盖。
- 支持幂等 task 接收、消息 upsert、按序号增量 sync。
- 给出可执行迁移方案并在客户端接入新接口。

# Implementation Plan (phased)
1. 新增数据库表：`chat_tasks`、`chat_messages`、`chat_sync_checkpoints`，形成 task lifecycle + append/update log + session checkpoint 三层模型。
2. 后端新增服务与路由：
   - `POST /api/chat/tasks/accept`（幂等接收）
   - `PUT /api/chat/messages/batch`（消息批量 upsert）
   - `GET /api/chat/sync/:sessionId?afterSeq=`（增量拉取）
3. 客户端新增异步聊天 API 服务，接入 `acceptTask` + `upsertMessages` + `sync`。
4. `ChatScreen` 改造为：发送时上报 task accepted；消息变化时批量 upsert；初始化/切换 scope 时通过 sync 拉取并重建状态。
5. 迁移策略：
   - 先上线双写（保留旧 `chat_sessions` 读路径兼容）；
   - 稳定后将读切到 `chat_messages`；
   - 运行离线 backfill（把 `chat_sessions.messages` 展平成 `chat_messages`）；
   - 验证完成后下线旧快照写入。

# Acceptance Criteria
- 后端具备 task 接收幂等能力和消息日志增量同步能力。
- 刷新/重连后可用 `afterSeq` 拉取缺失消息，不依赖全量覆盖。
- 多 Agent 接话消息按服务端序列可重放，历史不会被并发覆盖。
- `apps/node_backend` 类型检查/测试与 `apps/mobile_chat_app` 相关测试通过。
