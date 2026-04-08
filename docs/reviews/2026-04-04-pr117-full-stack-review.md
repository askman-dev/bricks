# PR117 全栈代码审查（需求 → 后端 → 架构 → 数据库 → 客户端）

## 1) 需求审查
### 已落地
- 客户端已具备 bot/skill 类型化注册与解析。
- 消息元数据已能表达 task、channel/session/thread、仲裁结果的关键字段。

### 关键缺口
- 需求文档中的“LLM judge 输出 schema + 后端裁决”仍未形成真正的服务端闭环。
- 当前仍为本地仲裁，不具备跨端一致性与可追溯审计链路。

## 2) 后端审查（Node API）
### 现状
- 现有 backend 主要提供 auth/config/llm 能力，缺少 chat arbitration/task 相关 API。

### 风险
- 客户端自决策会导致多端行为不一致。
- 无法在服务端做灰度策略、限流与审计指标。

### 建议
1. 增加 `/chat/tasks` 提交与 ack API。
2. 增加 `/chat/arbitration/decide`，由后端统一执行 bot routing。
3. 回包包含 `trace_id`、`decision_version`、`candidate_scores`。

## 3) 架构审查
### 已改进
- 本次已将仲裁、任务协议、拓扑解析拆分为独立模块，减少 UI 与路由耦合。

### 待改进
- 缺少 transport 层接口抽象（当前仍由 Screen 直接 orchestrate）。
- `ChatThread` 仍处于弱使用状态，建议引入 repository/service 统一管理。

## 4) 数据库审查
### 现状
- node_backend migrations 尚无 chat task / arbitration / channel-thread-session 表。

### 风险
- 无法做 checkpoint 恢复、历史回放、策略评估。

### 建议表模型（最小集）
- `chat_tasks(task_id, user_id, channel_id, session_id, thread_id, idempotency_key, state, created_at, acked_at)`
- `chat_task_checkpoints(task_id, cursor, synced_at)`
- `chat_arbitration_traces(trace_id, task_id, selected_bot_id, selected_skill_id, tie_detected, reason, created_at)`
- `chat_arbitration_scores(trace_id, bot_id, score, confidence, reason)`

## 5) 客户端审查
### 本轮修复
- 将仲裁分数从 botId 派生逻辑切换为“参与者概率权重”驱动，避免伪随机决策。
- 增加 empty-candidate 场景测试，确保可回退默认 bot。

### 仍需推进
- 与后端裁决接口对接，客户端仲裁降级为本地 fallback。
- 将 cursor/checkpoint 与真实后端同步协议联动。

## 结论
当前客户端基础能力已从“演示态”进入“可扩展态”，但后端与数据库层仍缺正式契约与持久化设计。建议下一阶段优先完成服务端仲裁与任务状态存储，客户端改为消费后端决策结果。
