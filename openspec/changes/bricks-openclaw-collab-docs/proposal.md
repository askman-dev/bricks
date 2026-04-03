# Proposal: Bricks × OpenClaw 第一阶段（仅插件设计）

## What

将原先较宽泛的 Bricks × OpenClaw 协同文档收敛为**第一阶段：仅聚焦 OpenClaw Channel Plugin 设计**，目标是打通最小可行消息闭环：

1. 网页客户端发送消息到 Bricks 服务器并落库；
2. 服务器通过 OpenClaw 插件能力把消息交给 Claude/OpenClaw 处理；
3. Claude 产生回复后，通过插件回传到 Bricks 服务器；
4. 服务器再把回复同步给客户端（优先拉取一致性，可选推送优化）。

## Why

当前最紧迫问题不是完整系统分层，而是验证“**消息如何经由插件完成双向流转**”。
如果插件边界不清晰，后续后端/客户端方案会反复返工。

因此本次提案采用“先打通链路、再扩展能力”的简化策略：

- 暂缓复杂多 Agent 编排细节；
- 暂缓完整客户端组件体系；
- 先完成 OpenClaw 插件职责、生命周期、收发路径与回执机制定义。

## Non-goals

- 不在本提案内实现完整业务代码；
- 不设计 OpenClaw/Claude 内部推理细节；
- 不扩展到完整权限系统矩阵与全量 UI 组件。

## Key Decisions

- 以官方 Channel Plugin 能力为准绳：`defineChannelPluginEntry` + `createChatChannelPlugin`。
- 入站（平台 -> OpenClaw）由插件在 `registerFull` 注册 HTTP route/webhook 后转发处理。
- 出站（OpenClaw -> 平台/Bricks）由插件 `outbound` 适配器负责发送，并返回 message metadata。
- Bricks 与插件通信建议采用“事件投递 + 状态查询”双通道，保证离线可恢复。

## Deliverables

- `design.md`：仅保留插件导向的最小闭环设计与时序。
- `tasks.md`：插件能力调研、接口定义、PoC 验证任务。
