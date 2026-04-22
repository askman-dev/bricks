# Chat / Platform 路由流式能力与输出边界调研（2026-04-22）

## 结论概览

| 路由 | 当前返回模式 | 是否支持“动态推送到用户” | 粒度 | 现状边界 | 本次建议/实现 |
|---|---|---|---|---|---|
| `POST /api/llm/chat` | 一次性 JSON | 否 | 完整文本一次返回 | `maxTokens` 之前无上限约束 | 新增 `maxTokens` 正整数校验，默认/上限 120K |
| `POST /api/llm/chat/stream` | SSE (`text/event-stream`) | 是 | 模型 token/文本分片 (`text-delta`) | `maxTokens` 之前无上限约束 | 新增 `maxTokens` 校验，默认/上限 120K，保持增量推送 |
| `POST /api/chat/respond` | 快速 ack（异步） | 通过既有 SSE 间接实现 | assistant 同一消息增量修订 | 默认模型调用 1024，未统一校验请求里的 `maxTokens` | 新增 `maxTokens` 校验并透传；default router 改为模型流式落库 |
| `GET /api/chat/sync/:sessionId` | 轮询 JSON | 间接是（靠客户端轮询） | message 级 | 无内容长度边界 | 不变（由写入路径边界控制） |
| `GET /api/chat/events/:sessionId` | SSE（服务端轮询 DB） | 是 | message 批次级（每秒 poll） | 无内容长度边界 | 不变（由写入路径边界控制） |
| `POST /api/v1/platform/messages` | 一次性 JSON（写入） | 否（写接口） | N/A | 文本长度无上限 | 新增 text/content 长度上限 120K 字符 |
| `PATCH /api/v1/platform/messages/:messageId` | 一次性 JSON（更新） | 否（写接口） | N/A | 文本长度无上限 | 新增 text 长度上限 120K 字符 |
| `GET /api/v1/platform/events/stream` | SSE（服务端轮询 DB） | 是（给插件侧） | event 批次级 | 事件 limit 最大 200（拉取接口） | 不变（内容长度受消息写入边界影响） |

## 分路由说明

### 1) `POST /api/llm/chat`
- 这是非流式接口，模型结果最终以单次 JSON 返回。
- 适合“需要完整结果后再展示”的场景，不满足用户端实时打字机效果。

### 2) `POST /api/llm/chat/stream`
- 这是真正流式接口，后端按 `for await (const chunk of textStream)` 持续发送 SSE `text-delta`。
- 用户端可边收边渲染，具备“动态输出”的能力。

### 3) `POST /api/chat/respond` + `GET /api/chat/events/:sessionId`
- `respond` 本身不是流式，仅负责受理任务并返回 accepted。
- 用户侧“动态看到结果”依赖 `events/:sessionId`（SSE）或 `sync/:sessionId`（轮询）。
- default router 已改为后台流式请求模型并持续写回同一 assistant 消息，前端可通过既有 `events/:sessionId` 看到内容逐步增长（消息修订级实时）。
- 对 openclaw router，如果插件多次 `PATCH /messages/:id` 或分段 `POST /messages`，则也可形成近实时增量感知（本质是消息修订/追加驱动）。

### 4) 平台接口 `POST/PATCH /api/v1/platform/messages*` + `GET /api/v1/platform/events/stream`
- `messages` 系列是写入接口，不是推送接口。
- `events/stream` 是推送接口（SSE），但推送对象是插件消费者（读取待处理事件），非最终用户 UI。
- 架构上仍可满足“远端产生一点 -> 后端记录一点 -> 立即对订阅端推送一点”，只是粒度是事件/消息级，而非严格 token 级。

## 边界上限可行性评估

1. **token 级动态输出（最强实时）**
   - 可由 `POST /api/llm/chat/stream` 直接达成。
   - 适用默认 LLM 直连链路。

2. **message 级动态输出（较实时）**
   - 可由 `POST /api/chat/respond` + `GET /api/chat/events/:sessionId` 达成。
   - 当前 default router 已改为流式分片落库，用户可在同一 assistant 消息上看到持续增长。

3. **插件链路动态输出**
   - 取决于插件是否采用“分段写入/patch”策略。
   - 后端路由能力上可支持持续更新并通过 SSE 推送给订阅方。

## 本次实现的输出长度边界

- `maxTokens` 统一约束：
  - 默认值：120K
  - 上限：120K
  - 적용到：`/api/llm/chat`、`/api/llm/chat/stream`、`/api/chat/respond`（default router 异步生成）
- 平台消息文本长度：
  - 上限：120K 字符
  - 적용到：`POST /api/v1/platform/messages`、`PATCH /api/v1/platform/messages/:messageId`

## 仍可增强的点（后续）

1. 引入按模型/路由可配置边界
   - 当前上限是固定常量，可后续放到配置中心。
2. 增加 observability
   - 记录每次请求的 tokens 预算、实际输出长度、截断/拒绝原因，便于容量治理。
