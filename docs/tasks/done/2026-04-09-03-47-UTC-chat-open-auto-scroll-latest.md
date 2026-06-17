# Background
在聊天页面已有历史消息时，用户打开对话后仍需要手动滑动才能看到最新消息，影响阅读与继续对话体验。

# Goals
- 进入已有历史的对话后自动定位到底部（最新一条消息）。
- 当消息列表内容替换但条数不变时，也能触发自动滚动到底部。
- 保持现有发送与增量更新流程不受影响。

# Implementation Plan (phased)
## Phase 1: MessageList 自动滚动触发条件增强
1. 在 `MessageList` 中新增“最后一条消息签名”对比逻辑，不仅比较 `length`，还比较尾消息内容/时间等关键字段。
2. 当签名变化时触发 `_scrollToBottom()`，覆盖“长度不变但历史内容已切换”的场景。

## Phase 2: 回归验证
1. 新增/更新 widget 测试，验证列表初次渲染时会定位到最新消息。
2. 运行 Flutter 相关测试确保改动稳定。

# Acceptance Criteria
- 打开有历史消息的对话后，无需手动拖动即可看到最新消息。
- 在消息总数不变但内容切换后，仍会自动滚到末尾。
- 相关测试通过（`./tools/init_dev_env.sh`、`cd apps/mobile_chat_app && flutter test test/message_list_test.dart`）。
