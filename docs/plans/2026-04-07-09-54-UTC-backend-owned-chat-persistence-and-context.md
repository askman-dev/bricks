# Background
用户对上一版修复提出进一步要求：
1) 发送后可关闭客户端，后续再次进入仍可看到完整回复；
2) 历史拼接应在后端，便于统一裁剪策略；
3) 存储应由后端完成，不应依赖客户端再次回传整段历史；
4) 评估 accept 与 chat 并行是否必要。

# Goals
1. 将单轮问答的落库与生成尽量收敛到后端一次编排中完成。
2. 在后端按可控策略读取/裁剪历史上下文并用于模型调用。
3. 前端发送路径改为调用后端编排接口，减少“先客户端算、再客户端回传存储”的依赖。
4. 保持兼容现有接口，同时为后续精简 `accept` 铺路。

# Implementation Plan (phased)
## Phase 1
- 后端新增 `POST /api/chat/respond`：接收任务信息 + 用户消息，完成：accept（幂等）-> 用户消息落库 -> 读取并裁剪会话历史 -> LLM 生成 -> assistant 落库。
- 服务层新增按 session 拉取历史消息并裁剪的函数（条数/字符上限）。

## Phase 2
- 前端新增 `ChatHistoryApiService.respond`。
- 主发送流程 `_sendMessage` 改为调用 `respond` 获取最终文本并更新 UI；保留历史同步机制。

## Phase 3
- 回归执行 Node type-check、Node tests、Flutter 相关测试。

# Acceptance Criteria
1. 用户发送消息后，只要请求已被后端接收，即使客户端关闭，后端仍可完成回复并持久化。
2. 模型请求历史由后端从数据库读取并裁剪，不依赖前端拼接完整历史。
3. assistant 最终内容由后端写库，刷新后可直接从 history/sync 读到。
4. 现有测试通过，新增改动无编译错误。
