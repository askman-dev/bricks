# Background
用户反馈在频道里发送消息并收到 AI 回复后，刷新页面会丢失历史对话，导致无法继续在同一上下文聊天。当前 `ChatScreen` 仅将消息保存在内存 `_messages`，没有持久化或启动时恢复流程。

# Goals
- 将用户消息和 AI 回复持久化存储。
- 页面刷新/重启后恢复之前的会话消息。
- 继续兼容当前频道/线程会话模型，不破坏发送与流式更新行为。

# Implementation Plan (phased)
1. 在 `ChatScreen` 引入会话持久化服务（基于 `SharedPreferences`），按当前 scope（channel + thread）保存消息列表。
2. 在初始化流程完成后加载持久化消息并恢复 `_messages`，同时恢复最近 checkpoint cursor（如有）。
3. 在消息增删改（append/update/stream completion/error/cancel）后自动触发持久化。
4. 在切换频道、切换子区、创建频道/子区后，加载目标 scope 对应历史消息。
5. 添加单元测试覆盖：消息序列化 round-trip、scope key 生成、持久化读写基本行为。

# Acceptance Criteria
- 发送消息并收到 AI 回复后刷新页面，消息仍显示，且可继续发送新消息。
- 切换到不同频道/子区时，能加载对应历史，不与其他 scope 串线。
- `flutter test`（至少针对 `apps/mobile_chat_app`）通过。
