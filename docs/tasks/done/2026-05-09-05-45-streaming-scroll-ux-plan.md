# Background
当前 `MessageList` 在消息列表发生变化时，会重新聚焦“最新用户消息”。在流式输出阶段，若尾消息标识变化（例如 messageId 补齐或快照字段变化），会触发再次滚动，造成可视区域被不断“往上顶”，底部出现大面积空白，影响阅读体验。

# Goals
- 发送消息瞬间：自动将“最新用户消息”定位到靠上位置（保持现有对齐策略）。
- 流式输出阶段：不再因 assistant 增量输出强制滚动。
- 用户手动滚动后：不被后续 assistant 输出干预。
- 页面初次加载/刷新后：仍自动定位到最后一个用户问题。

# Implementation Plan (phased)
1. 调整 `MessageList.didUpdateWidget` 的自动滚动触发条件。
   - 仅在“新增的尾消息是 user（用户刚发送）”时触发自动聚焦。
   - 保留 `initState` 的初次定位逻辑，用于页面刷新后的自动定位。
2. 补充/调整 `message_list_test.dart`。
   - 新增测试：assistant 新消息追加时不应改变当前滚动位置。
   - 保留并验证：streaming 同尾增量时不重滚动。
3. 运行目标测试确保行为符合预期。

# Acceptance Criteria
- 当用户发送一条新消息时，列表自动将该用户消息定位到可视区靠上位置。
- 当 assistant 流式输出持续更新时，列表位置保持不变，除非用户主动点击“Jump to latest”。
- 页面首次进入（含刷新）时，仍自动定位到最后一个用户消息。
- 相关 widget tests 通过。

