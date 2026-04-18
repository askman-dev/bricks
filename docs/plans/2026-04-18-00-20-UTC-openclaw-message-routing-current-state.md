# OpenClaw 消息路由与读状态（当前有效基线）

## Background

为避免历史方案并存造成误解，本文件合并并替代以下旧文档中的阶段性结论：
- `2026-04-17-09-30-UTC-openclaw-web-read-state-test.md`
- `2026-04-17-10-25-UTC-openclaw-read-state-and-placeholder-removal.md`
- `2026-04-17-11-15-UTC-openclaw-platform-events-filter-investigation.md`
- `2026-04-17-11-50-UTC-openclaw-full-flow-test-coverage-review.md`

## Goals

1. 定义 OpenClaw 路由下“已发送未读 / 已读并回复”的**当前**语义与数据形态。
2. 明确平台事件过滤条件与空事件排查入口。
3. 给出当前测试覆盖边界与后续补强重点。

## Implementation Plan (phased)

### Phase 1 — 当前行为基线（已生效）
- OpenClaw 异步发送不再持久化 assistant 站位消息行。
- `respond` 在 OpenClaw 路由下返回 `mode=async`, `state=accepted`, `text=''`。
- 用户消息通过属性表达状态演进：
  - `accepted/dispatched`：已发送待插件消费。
  - 插件 ACK 后更新为 `completed`，并记录 `metadata.pluginReadBy.<pluginId>`。

### Phase 2 — 平台事件供给条件（已生效）
`/api/v1/platform/events` 返回事件时，需满足：
- `write_seq > cursor`
- `role = 'user'`
- `task_state IN ('accepted','dispatched')`
- `metadata` 含 `pendingAssistantMessageId`
- 若 JWT 带 `userId`，还需匹配 `msg.user_id = token.userId`

### Phase 3 — 空事件排查（当前推荐顺序）
1. 核对 cursor 是否已追平。
2. 核对 JWT `userId` 与消息归属用户是否一致。
3. 核对消息是否满足 role / task_state / metadata 过滤条件。
4. 核对插件请求头 `X-Bricks-Plugin-Id` 与 token claim/plugin scope 是否一致。

### Phase 4 — 测试覆盖现状与补强方向
- 当前覆盖是“分段覆盖”：
  - 前端 `respond` 状态映射
  - 后端 OpenClaw `respond` 行为
  - 平台鉴权与 userId 透传
  - 平台 events/ack 服务逻辑
- 尚缺“单用例闭环集成测试”串联：
  - `respond -> events -> messages(create/patch) -> ack -> sync`

## Acceptance Criteria

1. 仓库仅保留本文件作为 2026-04-17 这一组 OpenClaw 消息路由调整的有效基线。
2. 旧阶段性文档删除并由本文件统一承接。
3. 代码地图索引仅指向本文件，不再指向旧文档。

### Validation commands

- `git diff -- docs/plans docs/code_maps/logic_map.yaml`
