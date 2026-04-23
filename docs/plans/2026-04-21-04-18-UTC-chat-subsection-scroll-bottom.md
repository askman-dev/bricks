# Background
- 当前移动端对话界面在右上角切换子分区后，会优先定位到“最新用户消息”而非对话流末尾。
- 这会导致进入分区后看不到最新助手输出或最新上下文末尾，影响连续阅读体验。

# Goals
- 切换到任意子分区（含主区）并加载消息后，列表应定位到对话流底部。
- 保持现有“流式回复增量更新时不重复强制滚动”的稳定性。
- 补齐/更新相关测试，防止滚动行为回归。

# Implementation Plan (phased)
1. **滚动逻辑调整（MessageList）**
   - 将 `MessageList` 的自动定位目标从“最新用户消息”调整为“列表底部”。
   - 保留现有基于 `_LastMessageKey` 的快照比较逻辑，避免流式增量阶段反复重置滚动。
2. **测试更新**
   - 更新 `message_list_test.dart` 中与“定位最新用户消息”相关的用例描述与断言，改为验证“定位到底部”。
   - 保持 streaming 场景测试，确保无 messageId 的流式增量仍不触发重滚。
3. **验证**
   - 执行仓库要求的环境初始化脚本。
   - 在 `apps/mobile_chat_app` 目录执行目标测试文件。

# Acceptance Criteria
- 切换分区后加载消息，列表自动停留在底部（可观测为 `pixels == maxScrollExtent` 或等价近似）。
- 当仅发生流式内容追加且尾消息身份未变时，不触发额外自动滚动。
- `apps/mobile_chat_app/test/message_list_test.dart` 相关用例通过。
- 验证命令：
  - `./tools/init_dev_env.sh`
  - `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
