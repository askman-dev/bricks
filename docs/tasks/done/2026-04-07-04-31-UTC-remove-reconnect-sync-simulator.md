# Background
用户要求移除聊天页面“模拟断线恢复同步”按钮，并删除对应模拟恢复能力，避免在正式交互流程中保留调试入口。

# Goals
1. 从聊天页面 UI 中移除“模拟断线恢复同步”按钮。
2. 删除 `_simulateReconnectSync` 相关状态与逻辑实现。
3. 保持聊天主流程（发送、展示、线程等）不受影响并通过静态检查。

# Implementation Plan (phased)
## Phase 1: Remove UI entry
- 删除 `chat_screen.dart` 中底部 `TextButton.icon`（sync 图标 + “模拟断线恢复同步”文案）。
- 删除仅为该能力服务的同步进度条展示。

## Phase 2: Remove simulation logic
- 删除 `_syncingAfterReconnect` 状态字段。
- 删除 `_simulateReconnectSync()` 方法。
- 删除 Context Bar 中 `Syncing…` 的条件展示。

## Phase 3: Validate
- 运行仓库初始化脚本并执行 Flutter 分析命令，确认无编译/静态检查错误。

# Acceptance Criteria
- 界面中不再出现“模拟断线恢复同步”按钮。
- 代码中不再包含 `_simulateReconnectSync` 与 `_syncingAfterReconnect`。
- `flutter analyze` 对相关文件通过。
