# Background
当前聊天页在首次进入或切换会话后，会将视口锚定到“最后一条 user 消息”，而不是“最后一条消息（通常是 assistant 最新回复）”。这会导致用户打开页面时看不到真正最新内容，和产品预期不一致。后端历史接口已支持按 `limit` 仅回放最近消息，满足“消息太多可暂不加载早期消息”的方向。

# Goals
1. 会话加载/切换后，消息列表自动定位到最后一条消息。
2. 保留现有“只拉取最近一段历史（limit）”行为，不回退为全量加载。
3. 更新并通过 `MessageList` 相关测试，防止滚动锚点回归。
4. 同步更新代码地图中与滚动锚点相关的描述。

# Implementation Plan (phased)
## Phase 1: 调整消息列表锚点逻辑
- 在 `MessageList` 中把“focused index”从“latest user”改为“latest message”。
- 将滚动方法命名与注释同步为“latest message”语义，避免后续误解。

## Phase 2: 更新与补强测试
- 更新 `apps/mobile_chat_app/test/message_list_test.dart` 中用例名称与断言语义。
- 确保首次渲染、列表变化、同实例变更场景都验证“定位到最后一条消息”。

## Phase 3: 文档与索引同步
- 更新 `docs/code_maps/feature_map.yaml` 与 `docs/code_maps/logic_map.yaml` 中 chat_session 的滚动锚点描述，反映“最后一条消息”策略。

# Acceptance Criteria
1. 打开或切换到有历史消息的会话时，视口定位到最后一条消息（最新内容）而非最后一条 user 消息。
2. 历史仍通过 `limit` 加载最近消息，不强制加载全量历史；向上滚动触顶再加载早期消息可继续作为后续增强。
3. `apps/mobile_chat_app/test/message_list_test.dart` 全部通过。
4. 代码地图中 chat_session 对滚动行为描述与实现一致。

## Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
