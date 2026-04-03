# Tasks: 插件优先闭环（Phase 1）

## A. 调研与接口冻结

- [x] 基于 OpenClaw 官方文档确认 Channel Plugin 核心能力与入口形式
- [x] 明确 inbound/outbound 在本方案中的职责分工
- [x] 输出 Bricks -> Plugin 与 Plugin -> Bricks 最小接口草案

## B. PoC 任务（仅闭环）

- [ ] 在 Bricks 增加 `POST /plugin-bridge/openclaw/dispatch`（或等价服务间入口）
- [ ] 在插件侧实现 dispatch 接收与 OpenClaw 调用链路
- [ ] 在插件侧实现 `POST /callbacks/openclaw/messages` 回调至 Bricks
- [ ] 在 Bricks 端完成 callback 验签、幂等落库、任务状态推进
- [ ] 在客户端验证 cursor 重连可见性（断网后恢复）

## C. 验收

- [ ] 单条消息从网页发出后，可在 Bricks 与插件日志中追踪同一 `task_id`
- [ ] Claude 回复可在 1 次或多次重试后可靠回传并最终落库
- [ ] 客户端不依赖 websocket 也能拉到完整回复
