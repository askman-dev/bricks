# Background

随着仓库规模增大，AI Agent 在修改代码时容易遗漏关联逻辑，导致遗留代码或功能回归。需要建立“代码地图”作为统一缩略图入口，帮助人类测试员、AI 测试员与 AI 工程师快速定位功能路径和文档索引。

# Goals

1. 新增功能地图 YAML，记录功能列表与进入路径。
2. 新增逻辑地图 YAML，记录功能与代码/文档索引、关键词映射。
3. 新增可复用的 Codex Skill，用于指导后续如何维护代码地图。
4. 在 AGENTS 记忆中加入“改代码后同步维护代码地图”的工作约束。

# Implementation Plan (phased)

## Phase 1 - 代码地图文件落地

- 创建 `docs/code_maps/feature_map.yaml`。
- 创建 `docs/code_maps/logic_map.yaml`。
- 定义统一字段，保证人类与 AI 均可解析。

## Phase 2 - 维护 Prompt 规范化

- 新建 `.codex/skills/code-map-maintainer/SKILL.md`。
- 写明触发条件、维护步骤、变更后检查点与输出格式。

## Phase 3 - Agent 记忆接入

- 更新根目录 `AGENTS.md`：
  - 将 `code-map-maintainer` 注册进可用 skills 列表。
  - 增加“代码变更后应检查并维护代码地图”的常驻规则。

## Phase 4 - 基础校验

- 执行 YAML 解析校验，确保新增地图文件格式正确。

# Acceptance Criteria

1. 存在且仅存在两份代码地图 YAML：功能地图与逻辑地图。
2. 功能地图可读出每个功能的入口路径与验证入口。
3. 逻辑地图可读出功能对应的代码索引/文档索引与关键词。
4. 仓库内存在维护代码地图的独立 skill 文档，并可被后续任务引用。
5. AGENTS 说明包含“代码变更后维护代码地图”的明确记忆约束。
