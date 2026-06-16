# Background
目前移动端聊天侧边栏已有 `Agents` 分组，但其内容仅来自本地 Agent 文件仓库（`AgentsRepository`）读取结果；在未创建任何 Agent 时会显示空状态文案。现有 Agent 定义已包含 `name`、`description`、`model`、`systemPrompt`，与“BOT = system prompt + 模型选项（可选）”方向高度一致，但命名与产品语义仍需统一。

# Goals
1. 明确现状：梳理 Agent 在域模型、存储、运行时、UI 侧边栏的现有设计与数据流。
2. 给出 BOT 概念映射：将“BOT 内核概念”映射为用户可见 `Agent`，并保证兼容既有实现。
3. 提出可落地改造分期：让侧边栏 `Agents` 分组内置并稳定展示可用 BOT（如文档、问答、问卷、儿童 workbook）。

# Implementation Plan (phased)
## Phase 1 - 概念与命名统一（不改协议）
- 在产品与文档层统一术语：
  - **用户层名称**：Agent（侧边栏继续显示 Agent）
  - **内部设计名称**：BOT（prompt-profile + model-profile 的可运行单元）
- 定义字段映射：
  - `bot_id` -> 现有 `AgentDefinition.name`
  - `display_name` -> 新增展示名（可选，未配置时回落为 `name`）
  - `system_prompt` -> 现有 `systemPrompt`
  - `model_profile` -> 现有 `model`（后续可扩展 provider、temperature 等可选项）

## Phase 2 - 内建 BOT 注册表
- 新增“内建 BOT 清单”模块（建议在 chat_domain 或 mobile_chat_app feature 层）：
  - 至少包含：写文档、轻松问答、问卷、儿童 workbook。
- 启动时合并来源：
  - 内建 BOT（只读）
  - 用户自建 Agent/BOT（可编辑）
- 侧边栏展示按分组或标记区分（Built-in / Custom）。

## Phase 3 - 侧边栏与入口联动
- `ChatNavigationPage` 的 Agents 分组改为显示“合并后的 Agent 列表”。
- 空状态逻辑调整：当用户自建为空时仍显示内建 BOT，不再出现“分组空”的主路径体验。
- “配置”入口从未实现状态接入可用页面：
  - 内建 BOT：仅允许复制为自定义版本（避免直接破坏默认模板）
  - 自建 BOT：可编辑 system prompt 与模型选项。

## Phase 4 - 运行时选择与审计
- 发送消息时把当前选中 Agent/BOT 的 `bot_id`、`system_prompt_version`、`resolved_model`记录到消息元数据，便于回放与排障。
- 与现有 `ChatBotRegistry`（ask/image_generation）关系：
  - 短期并存：保留 skill 级路由；新增 BOT 层用于 persona/prompt 封装。
  - 中期收敛：把默认 ask 也迁移为内建 BOT 的一个实例。

# Acceptance Criteria
1. 新安装或未创建自定义 Agent 的用户，打开侧边栏 `Agents` 分组时可见内建 Agent 列表（至少 4 个）。
2. 用户可明确区分“内建 Agent”和“自定义 Agent”。
3. 选择任一 Agent 发送消息后，运行时使用该 Agent 的 system prompt；模型选项未指定时按默认策略回退。
4. 保持向后兼容：旧 `.md` Agent 文件仍可加载并显示。
5. 验证命令（开发阶段）：
   - `./tools/init_dev_env.sh`
   - `cd apps/mobile_chat_app && flutter test`
