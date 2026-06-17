# Background
PR #117 的评论指出多项“计划文档已写但代码未实现”的缺口，尤其集中在 bot arbitration、channel/thread/session 语义和 async task 生命周期。需要统一补齐可运行的基础实现，而非零散修补。

# Goals
1. 建立可复用的类型化协议：Bot/Arbitration、Channel/Thread/Session、Task/Ack/Checkpoint。
2. 将上述协议接入 ChatScreen 主流程（发送、路由、恢复同步、上下文展示）。
3. 增加回归测试，覆盖 tie fallback、default channel 解析和 task ack 状态推进。

# Implementation Plan (phased)
## Phase 1: 协议与实体建模
- 新增 `chat_arbitration.dart`：候选评分、决策结果、tie 检测和默认回退。
- 新增 `chat_topology.dart`：`ChatChannel`/`ChatThread`/`ChatSessionScope` 及 default channel 解析。
- 新增 `chat_task_protocol.dart`：task envelope、ack、checkpoint 以及 message 状态推进。
- 扩展 `ChatMessage` 元数据字段，覆盖 idempotency、acknowledged_at、cursor、tie 相关字段。

## Phase 2: 发送链路整合
- `ChatScreen` 使用 arbitration engine 做统一决策，不再只靠单点布尔分支。
- 发送时生成 envelope + ack，落盘到消息元数据并展示 cursor。
- 引入 thread mode 显式开关，仅开启后允许创建子区。
- 断线恢复模拟改为 checkpoint-aware 行为。

## Phase 3: 测试
- 新增 arbitration engine 测试（最高分选择、tie 回退默认 bot）。
- 新增 topology + task protocol 测试（default channel、ack 状态推进）。

# Acceptance Criteria
- 多候选 bot 场景可输出结构化 arbitration 结果并在 tie 时回退默认 bot。
- 缺失/非法 channel 请求会解析到默认 channel。
- 消息在 ack 后具备 `dispatched` 状态与 checkpoint cursor。
- `flutter test` 覆盖新增测试并通过。
