# Background
根据已完成的 Agent/BOT 方案文档，当前需要把“侧边栏 Agent 分组默认可见内建 BOT、并支持配置入口”落地到代码，而不是仅停留在计划层。

# Goals
1. 在未创建自定义 Agent 时，侧边栏仍展示内建 Agent（BOT）。
2. 将“配置”按钮从占位提示改为可执行入口。
3. 在侧边栏区分内建与自定义 Agent。

# Implementation Plan (phased)
## Phase 1 - 内建 BOT 注册
- 新增 `chat_builtin_agents.dart`，提供 4 个内建 Agent 模板：
  - doc-writer
  - easy-qa
  - survey-designer
  - kids-workbook

## Phase 2 - 合并加载与运行时接入
- `ChatScreen` 在读取自定义 Agent 后，与内建 Agent 合并。
- 保持自定义 Agent 优先（同名覆盖内建）。
- 继续复用现有 `_settingsForAgent`，使 system prompt / model 流程保持兼容。

## Phase 3 - 侧边栏展示与配置入口
- 扩展 `ChatAgentItem` 支持 `description` 与 `isBuiltIn`。
- 侧边栏 Agent 列表展示来源标签（内建/自定义），内建显示只读图标。
- 将“配置”按钮行为改为触发 `manageAgents` 动作，接入 `AgentsScreen`。

## Phase 4 - 测试与代码地图
- 更新 `chat_navigation_page_test.dart` 覆盖新交互。
- 新增 `chat_builtin_agents_test.dart` 覆盖内建模板存在性。
- 同步更新 `docs/code_maps/feature_map.yaml` 与 `docs/code_maps/logic_map.yaml`。

# Acceptance Criteria
1. 侧边栏 Agents 分组在默认安装场景下不为空。
2. 点击“配置”可进入 Agent 管理流程。
3. 侧边栏可看到内建/自定义区分信息。
4. 相关 Flutter 测试通过。
