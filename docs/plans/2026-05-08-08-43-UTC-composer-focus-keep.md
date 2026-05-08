# Background
用户反馈聊天输入框在发送消息（点击发送按钮或按回车）后会丢失焦点，导致无法连续输入下一条消息，影响高频对话体验。

# Goals
- 修复发送后输入框失焦问题。
- 保持现有发送逻辑与流式状态控制不被破坏。
- 增加回归测试，覆盖“不可发送但可继续输入”的行为。

# Implementation Plan (phased)
1. 检查 `ComposerBar` 的输入框可用性与提交后状态切换逻辑，定位导致失焦的条件。
2. 调整输入框 `enabled` 条件，确保发送动作触发后在非流式阶段仍可保持可输入状态。
3. 新增/更新 widget test，验证在 `onSend == null`（发送不可用）但非流式时输入框仍可编辑。
4. 运行相关测试命令并记录结果。

# Acceptance Criteria
- 点击发送按钮或按回车发送后，输入框仍可保持焦点并继续输入。
- 在 `isStreaming == false` 时，即便 `onSend == null`，输入框仍可输入文本。
- 现有 `composer_bar_test` 全部通过。

# Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart`
