# Background

对话页顶部目前展示一排 `Chip`（Channel / Thread / Session / ThreadMode / Mode / Cursor / Seq）。这些信息主要用于调试会话作用域、同步状态和多代理仲裁状态，不属于核心聊天输入输出流程。目标是在真正删除前，先确认影响面与依赖逻辑，避免误伤同步与线程切换能力。

> **注意**：`Syncing` Chip 及其关联的内联线性进度条与"模拟断线恢复同步"按钮已在本 PR 中一并移除（同步指示器和调试触发入口均属于调试辅助 UI，不属于核心 context bar 展示信息）。当前剩余 Chip 如上所列。

相关实现位于 `apps/mobile_chat_app/lib/features/chat/chat_screen.dart` 的 `_buildContextBar()`，并在 `build()` 的 `body` 中固定插入。同步与游标数据由 `ChatHistoryApiService` 与消息流处理逻辑提供。

# Goals

1. 明确顶部按钮（Chip）各自语义及关联状态字段。
2. 区分“仅 UI 展示”与“业务逻辑实际依赖”。
3. 给出删除该排按钮前后需要回归验证的场景。
4. 识别潜在连带影响（调试可观测性、文案、测试）。

# Implementation Plan (phased)

## Phase 1 - 结构梳理

- 定位 `_buildContextBar()` 的调用位置与渲染条件。
- 追踪各 Chip 绑定字段的写入来源（channel 切换、thread 切换、历史加载、reconnect sync、task ack）。
- 确认这些字段是否被其他逻辑分支读取，而不只是展示。

## Phase 2 - 影响面判定

- 将字段按“强依赖逻辑字段”与“纯展示字段”分组：
  - 强依赖：`_activeChannelId`、`_activeSubSection`、`_threadModeEnabled`、`_sessionIdForScope`、`_lastSyncedSeq`、`_latestCheckpointCursor`。
  - 纯展示：`_buildContextBar()` 及其 `Chip` 文案本身。
- 识别和删除动作相邻的 UI：`_syncingAfterReconnect` 线性进度条、`模拟断线恢复同步` 按钮。
- 明确删除按钮不应影响的路径：发送消息、流式更新、线程切换、历史同步。

## Phase 3 - 删除前验证清单（建议）

- 手动回归：
  1. 主区发送消息并接收流式回复。
  2. 开启 Thread 模式并切换子区。
  3. 切换频道后确认 session scope 仍正确重载。
  4. 通过真实断网/恢复网络（或应用切后台后恢复连接）触发 reconnect sync，确认 `afterSeq` 增量同步仍生效，缺失消息会补齐且不会重复。
- 自动化补强（当前仓库无直接覆盖）：
  - 为 `chat_screen` 添加 widget test，至少验证 context bar 可配置隐藏后不影响消息列表与 composer 渲染。

# Acceptance Criteria

1. 影响面说明能逐项映射每个顶部 Chip 对应的状态与写入路径。
2. 结论明确：删除顶部 Chip 属于 UI 层变更，不应删除其背后状态维护逻辑。
3. 删除方案包含回归项，且覆盖 channel/thread/sync 三类高风险路径。
4. 若后续实施删除，需确保页面仍保留必要调试入口（例如开发模式日志或可折叠诊断面板）。
