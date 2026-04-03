# Design: Bricks × OpenClaw（插件优先最小闭环）

## 0. 范围声明

本版本只解决一个问题：
**Bricks 服务器如何通过 OpenClaw 插件完成“发给 Claude 与收回回复”的可靠闭环。**

不展开 OpenClaw 内部推理与多 Agent 编排。

---

## 1) 最小消息闭环（唯一主线）

```text
Web Client -> Bricks API -> DB(持久化)
                         -> Plugin Bridge -> OpenClaw/Claude
OpenClaw/Claude -> Channel Plugin outbound/inbound hook
                -> Bricks Callback API -> DB(持久化)
                -> Client Sync API (cursor pull; optional push)
```

### 1.1 客户端到服务器

- 客户端 `POST /messages`（含 channel/thread/session 标识与消息体）。
- Bricks 先落库，再返回 `200 + message_id + task_id`。
- 随后异步触发“投递到 OpenClaw 插件”的后台任务。

### 1.2 服务器到 OpenClaw（通过插件）

- Bricks 不直接耦合模型细节，只调用“插件桥接接口”（Plugin Bridge）。
- 插件桥接接口负责把 Bricks 消息转换为 OpenClaw 侧可处理事件。
- 失败重试采用幂等键：`task_id + attempt`。

### 1.3 OpenClaw 回复回传服务器

- 当 Claude 完成回复后，插件通过回调 API（例如 `POST /callbacks/openclaw/messages`）把结果回传 Bricks。
- Bricks 校验签名/令牌，落库为 assistant message，并更新 task 状态。

### 1.4 服务器同步给客户端

- 客户端以 cursor pull 获取 `seq > last_seq` 的增量消息作为一致性来源。
- 可选 websocket/push 仅用于降低延迟，不作为一致性依据。

---

## 2) OpenClaw 插件能力调研结论（2026-04-03）

> 结论来源于 OpenClaw 官方插件文档（见文末“调研来源”）。

### 2.1 适合本场景的能力

- `defineChannelPluginEntry`：定义 channel 插件入口。
- `createChatChannelPlugin`：用声明式方式组合 security/pairing/threading/outbound。
- `registerFull(api)`：注册运行时能力（包括 HTTP 路由/webhook）。
- `outbound` 适配器：负责发送消息，并可返回 `messageId` 等结果元数据。

### 2.2 “如何从服务器获取消息”

官方示例偏向“平台 webhook 入站 -> 插件转发到 OpenClaw”。
对 Bricks 场景建议两种实现：

1. **Push 模式（推荐起步）**：Bricks 主动调用插件桥接接口投递消息；
2. **Pull 模式（后续）**：插件定时向 Bricks 拉取待处理消息（需租约锁）。

第一阶段先实现 Push 模式，路径短、问题可观测。

### 2.3 “结束后如何告诉服务器”

利用插件运行时/出站流程，在 Claude 产出后执行 Bricks 回调：

- 回调最少字段：`task_id`, `channel_id`, `thread_id`, `role`, `content`, `provider_message_id`, `finished_at`。
- 回调必须带签名（HMAC）与重放保护（timestamp + nonce）。
- Bricks 按 `task_id` 幂等写入，避免重复回调造成脏数据。

---

## 3) 插件接口草案（先定协议，不绑实现）

### 3.1 Bricks -> Plugin Bridge

`POST /plugin-bridge/openclaw/dispatch`

```json
{
  "task_id": "t_123",
  "message_id": "m_123",
  "channel_id": "c_1",
  "thread_id": "th_9",
  "user_id": "u_7",
  "content": "请帮我总结这段文本",
  "context": {"history_window": 20}
}
```

返回：`202 Accepted` + `dispatch_id`。

### 3.2 Plugin -> Bricks Callback

`POST /callbacks/openclaw/messages`

```json
{
  "task_id": "t_123",
  "dispatch_id": "d_888",
  "channel_id": "c_1",
  "thread_id": "th_9",
  "role": "assistant",
  "content": "这是总结结果...",
  "provider_message_id": "oc_msg_456",
  "status": "completed",
  "finished_at": "2026-04-03T05:00:00Z"
}
```

---

## 4) 可靠性与安全（第一阶段最小集）

- 鉴权：Bricks -> Plugin 使用服务间 token；Plugin -> Bricks callback 使用 HMAC。
- 幂等：`task_id` 全链路唯一；callback 以 `task_id + provider_message_id` 去重。
- 可观测：记录 `dispatch_id`, provider latency, callback code, retry count。
- 失败恢复：
  - dispatch 失败进入重试队列；
  - callback 失败由插件重试并指数退避；
  - 客户端始终可通过 cursor pull 补齐结果。

---

## 5) 第一阶段验收标准（仅插件闭环）

1. 网页发送消息后，Bricks 能立即返回已受理。
2. 该消息可被成功投递到 OpenClaw 插件侧。
3. Claude 回复后，插件可回调 Bricks 并落库。
4. 客户端在断线重连后，仍可通过 cursor 拉到这条回复。

---

## 调研来源

- OpenClaw 官方：Building Channel Plugins
  https://docs.openclaw.ai/plugins/sdk-channel-plugins
- OpenClaw 官方：Building Plugins
  https://docs.openclaw.ai/plugins/building-plugins
- OpenClaw 官方：Plugin Architecture
  https://docs.openclaw.ai/plugins/architecture
