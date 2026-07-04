# Hermes Agent 插件对接调研计划

## Background
当前仓库已具备 OpenClaw 插件与多 Agent 能力。用户要求基于现有代码确认架构与接口后，评估对接 Hermes Agent 插件系统所需工作，以及对 Bricks platform 的平台侧要求。

## Goals
- 盘点仓库中现有 Agent/Plugin/MCP 相关架构与接口（以代码为准）。
- 明确现有 OpenClaw 插件实现可复用部分与缺口。
- 输出 Hermes Agent 插件对接清单（插件层、协议层、平台治理层）。
- 输出对 Bricks platform 的必要要求与建议优先级。

## Implementation Plan (phased)
### Phase 1: 代码基线盘点
- 阅读 docs 中插件架构与 OpenClaw 集成文档。
- 阅读 `apps/node_openclaw_plugin` 实现，确认 manifest、生命周期、认证、状态、回调通道。
- 阅读 `packages/agent_sdk_contract` 与 `packages/agent_core` 的 Agent/Tool/Skill/Session 合约。

### Phase 2: 接口映射分析
- 从现有接口抽取“平台能力清单”（会话、工具执行、事件流、设置、权限、存储）。
- 将能力清单映射到 Hermes 插件常见对接面（插件注册、工具暴露、MCP、hook、skills、配置）。
- 标出需新增适配层与可直接复用路径。

### Phase 3: 输出结论与实施建议
- 给出最小可行对接路径（PoC）与分阶段落地顺序。
- 给出平台级非功能要求（安全、隔离、可观测、版本治理）。
- 明确未知项与建议验证实验。

## Acceptance Criteria
- 结论中每个关键判断可追溯到仓库文件或具体命令输出。
- 对接清单至少覆盖：插件打包/注册、协议接入、工具调用、配置管理、鉴权与审计。
- 提供可执行的 next steps（按优先级排序）。
