# Proposal: Bricks × OpenClaw Phase 1 / 第一阶段（Plugin Design Only / 仅插件设计）

## What

将原先较宽泛的 Bricks × OpenClaw 协同文档收敛为**第一阶段：仅聚焦 OpenClaw Channel Plugin 设计**，目标是打通最小可行消息闭环：
Narrow the previously broad Bricks × OpenClaw collaboration document into **Phase 1: focused only on OpenClaw Channel Plugin design**, with the goal of establishing the smallest viable end-to-end message loop:

1. 网页客户端发送消息到 Bricks 服务器并落库；
   The web client sends a message to the Bricks server, where it is persisted.
2. 服务器通过 OpenClaw 插件能力把消息交给 Claude/OpenClaw 处理；
   The server passes the message to Claude/OpenClaw for processing through the OpenClaw plugin capability.
3. Claude 产生回复后，通过插件回传到 Bricks 服务器；
   After Claude generates a reply, the plugin sends it back to the Bricks server.
4. 服务器再把回复同步给客户端（优先拉取一致性，可选推送优化）。
   The server then synchronizes the reply back to the client, prioritizing pull-based consistency with optional push optimization.

## Why

当前最紧迫问题不是完整系统分层，而是验证"**消息如何经由插件完成双向流转**"。
The most urgent issue is not full system layering, but validating **how messages complete bidirectional flow through the plugin**.
如果插件边界不清晰，后续后端/客户端方案会反复返工。
If the plugin boundary remains unclear, subsequent backend and client work will likely be reworked repeatedly.

因此本次提案采用"先打通链路、再扩展能力"的简化策略：
Therefore, this proposal adopts a simplified strategy of "connect the flow first, then expand capabilities":

- 暂缓复杂多 Agent 编排细节；
  Defer complex multi-agent orchestration details.
- 暂缓完整客户端组件体系；
  Defer the full client component system.
- 先完成 OpenClaw 插件职责、生命周期、收发路径与回执机制定义。
  First define the OpenClaw plugin responsibilities, lifecycle, send/receive paths, and acknowledgment mechanism.

## Non-goals

- 不在本提案内实现完整业务代码；
  Implementing complete production business code in this proposal.
- 不设计 OpenClaw/Claude 内部推理细节；
  Designing OpenClaw/Claude internal reasoning details.
- 不扩展到完整权限系统矩阵与全量 UI 组件。
  Expanding to the full permission matrix and the complete set of UI components.

## Key Decisions

- 以官方 Channel Plugin 能力为准绳：`defineChannelPluginEntry` + `createChatChannelPlugin`。
  Use the official Channel Plugin capabilities as the baseline: `defineChannelPluginEntry` + `createChatChannelPlugin`.
- 入站（平台 -> OpenClaw）由插件在 `registerFull` 注册 HTTP route/webhook 后转发处理。
  For inbound traffic (platform -> OpenClaw), the plugin registers an HTTP route/webhook in `registerFull` and forwards the request for processing.
- 出站（OpenClaw -> 平台/Bricks）由插件 `outbound` 适配器负责发送，并返回 message metadata。
  For outbound traffic (OpenClaw -> platform/Bricks), the plugin `outbound` adapter is responsible for sending and returning message metadata.
- Bricks 与插件通信建议采用"事件投递 + 状态查询"双通道，保证离线可恢复。
  Communication between Bricks and the plugin should use a dual-channel approach of "event delivery + status query" to ensure offline recovery.

## Deliverables

- `design.md`：仅保留插件导向的最小闭环设计与时序。
  `design.md`: retain only the plugin-oriented minimal closed-loop design and sequence flow.
- `tasks.md`：插件能力调研、接口定义、PoC 验证任务。
  `tasks.md`: plugin capability research, interface definition, and PoC validation tasks.
