# Background
用户询问移动端聊天页面中“模拟断线恢复同步”按钮的用途，需要基于代码路径确认其真实行为与触发条件。

# Goals
1. 定位该按钮在 UI 中的挂载位置与点击事件。
2. 明确按钮触发后的状态变化、同步模拟时序与消息标记效果。
3. 输出可直接给产品/测试使用的简明说明。

# Implementation Plan (phased)
## Phase 1: Code discovery
- 在 `apps/mobile_chat_app/lib/features/chat/chat_screen.dart` 中定位“模拟断线恢复同步”文案与回调函数。
- 在同目录与 `widgets/message_list.dart` 中追踪恢复标记字段的展示逻辑。

## Phase 2: Behavior verification
- 阅读 `_simulateReconnectSync` 具体实现，确认空消息保护、同步中状态、延时、checkpoint 光标回填和 recovered 标记更新逻辑。
- 对照上下文栏（Context Bar）确认“Syncing…”状态可见性。

## Phase 3: Response drafting
- 汇总按钮用途、限制条件与用户可见反馈，形成中文说明。

# Acceptance Criteria
- 能说明该按钮是“模拟”用途而非真实网络重连。
- 能说明仅在已有消息时生效。
- 能说明点击后可见反馈（顶部 Syncing、消息 Recovered 标记、checkpoint 光标行为）。
