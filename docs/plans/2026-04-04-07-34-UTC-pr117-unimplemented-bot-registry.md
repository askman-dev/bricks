# Background
PR #117 的评论指出：当前实现里 bot/skill 仍是硬编码字符串，缺少类型化的 bot registry 与默认回退规则，属于已识别但未完成的功能。

# Goals
1. 为聊天模块补齐类型化 Bot/Skill 元数据模型。
2. 引入 Bot Registry，统一处理 bot 与默认 skill 解析。
3. 当请求的 bot 不存在或不可用时，显式回退到默认 `ask` bot。
4. 将该解析结果接入消息元数据（`resolvedBotId` / `resolvedSkillId` / fallback 标记）。

# Implementation Plan (phased)
## Phase 1: Domain model
- 新增 `ChatBot`、`ChatSkill`、`ChatBotRegistry` 与 `ResolvedChatDispatch` 类型。
- 内置默认 bot：`ask` 与 `image_generation`。

## Phase 2: Routing integration
- 在 `ChatScreen` 中用 registry 解析当前请求 bot。
- 去掉发送流程里对 skill id 的硬编码分支。

## Phase 3: Validation
- 新增单元测试覆盖：
  - 已注册 bot 的默认 skill 解析；
  - 未注册 bot 的默认回退；
  - bot 默认 skill 缺失时的安全回退。

# Acceptance Criteria
- 当 active agent 是 `image_generation` 时，消息包含 `resolvedSkillId=image_generation.default`。
- 当 active agent 未注册时，消息落到 `resolvedBotId=ask` 且 `fallbackToDefaultBot=true`。
- `flutter test` 通过新增与现有测试。
