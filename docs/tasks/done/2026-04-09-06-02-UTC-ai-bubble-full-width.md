# Background
- 现有聊天消息气泡对 user 与 assistant 使用统一最大宽度（约 75%）。
- 新需求要求保持 user 气泡宽度策略不变，同时将 AI 回复气泡扩展为全屏宽度，以提高阅读效率。

# Goals
- user 消息气泡继续沿用当前宽度规则（不变）。
- assistant 消息气泡在消息列表可用宽度内占满整行。
- 保持既有折叠/展开与自动定位行为不受影响。

# Implementation Plan (phased)
1. 在 `MessageList` 中拆分 user/assistant 气泡宽度约束：
   - user: 维持 `maxWidth = screen * 0.75`。
   - assistant: 使用整行宽度（依赖列表 padding 留白）。
2. 增加 widget 测试验证宽度差异：
   - 同屏渲染一条 user 与一条 assistant 消息。
   - 断言 assistant 气泡宽度显著大于 user，且接近列表可用宽度。
3. 运行目标测试确保回归通过。

# Acceptance Criteria
- user 消息气泡视觉宽度与改动前一致。
- assistant 消息气泡占满消息列表内容区域宽度。
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart` 通过。
