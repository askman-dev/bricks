# OpenClaw 插件优先闭环计划

## Background

上一版文档覆盖面过大。当前需求调整为“先只看插件设计”，优先打通网页消息经服务器到 OpenClaw，再由插件回传服务器并同步客户端的最小闭环。

## Goals

1. 将 OpenSpec 文档聚焦到插件职责与消息双向流。
2. 基于官方文档补齐插件能力调研结论。
3. 给出可执行的接口草案与 Phase 1 验收标准。

## Implementation Plan (phased)

### Phase 1: 调研
- 查阅 OpenClaw 官方插件文档（channel/plugin architecture）。
- 提炼可直接用于“服务器-插件-服务器”闭环的能力。

### Phase 2: 文档收敛
- 重写 proposal/design/tasks 为“插件优先”版本。
- 删除或下沉暂不需要的系统广域内容。

### Phase 3: 验收标准
- 增加最小闭环验收条目（dispatch/callback/cursor recovery）。
- 输出下一步 PoC 任务清单。

## Acceptance Criteria

- `design.md` 的主线是插件闭环，不再以全系统展开为主。
- 文档明确说明插件如何接收服务器消息、如何回传服务器。
- `tasks.md` 包含可执行的 PoC 任务与可观测验收项。
