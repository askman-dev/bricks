# Background

聊天页底部存在“模拟断线恢复同步”按钮，用于手动调用增量同步流程。该入口是调试性质功能，不属于用户核心对话流程。

本任务根据评审反馈，要求删除该入口，且不保留相关测试代码。

# Goals

1. 删除聊天页中的“模拟断线恢复同步”按钮。
2. 清理仅为该按钮服务的页面状态与方法。
3. 不新增、不保留与该模拟入口绑定的测试代码。

# Implementation Plan (phased)

## Phase 1 - UI 与状态清理

- 从 `chat_screen.dart` 移除按钮渲染节点。
- 移除 `_simulateReconnectSync()` 方法。
- 移除 `_syncingAfterReconnect` 状态及其 UI 绑定（context bar 的 `Syncing…` chip、线性进度条）。

## Phase 2 - 编译层验证

- 运行静态检查，确认删除后无未使用引用或类型错误。

# Acceptance Criteria

1. 聊天页不再显示“模拟断线恢复同步”按钮。
2. 页面中不存在 `_simulateReconnectSync` 与 `_syncingAfterReconnect` 的残留引用。
3. 本次提交不新增与该入口相关的测试代码。
