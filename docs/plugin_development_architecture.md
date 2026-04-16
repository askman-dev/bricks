# 插件开发架构文档（Platform Plugin Architecture）

> 面向 OpenClaw / 小龙虾 等外部插件对接方。
> 本文档聚焦：**代码结构** + **使用方法**。

## 1. 架构目标

当前仓库的插件能力是“平台 API 层 + 业务服务层 + 移动端发 Token 辅助”的组合：

- 后端提供统一的插件 API 前缀：`/api/v1/platform/*`
- 插件通过 Bearer Token + `X-Bricks-Plugin-Id` 访问
- 数据复用现有聊天存储（`chat_messages`），不引入新的插件专用消息表
- 移动端设置页可生成并复制插件 Token，便于远端服务接入

---

## 2. 代码结构总览

```text
docs/
  plugin_development_architecture.md          # 本文档

apps/node_backend/src/
  app.ts                                      # 注入 platform 路由入口
  middleware/
    platformAuth.ts                           # 插件鉴权、scope 校验、token 签发
  routes/
    platform.ts                               # 平台 API 协议层（events/ack/messages/resolve）
    config.ts                                 # /api/config/platform-token（签发 token）
    platform.test.ts                          # 平台路由鉴权与约束测试
  services/
    platformIntegrationService.ts             # 平台协议与 chat_messages 的读写映射

apps/mobile_chat_app/lib/features/settings/
  llm_config_service.dart                     # 拉取 platform token
  model_settings_screen.dart                  # UI：生成/展示/复制 token

apps/mobile_chat_app/test/
  model_settings_screen_test.dart             # Token 交互与复制行为测试
```

---

## 3. 后端分层设计

### 3.1 路由入口层（`app.ts`）

职责：把平台接口挂载到统一 API 树。

- 新增：`app.use('/api/v1/platform', platformRoutes);`
- 效果：插件流量进入同一 Express 生命周期（限流、错误处理、迁移保护等）

### 3.2 鉴权中间件层（`platformAuth.ts`）

职责：完成插件身份、插件标识和 scope 的边界校验。

支持两种访问模式：

1. **静态 Key 模式**
   - `Authorization: Bearer <BRICKS_PLATFORM_API_KEY>`
   - 适合内网/固定服务对接

2. **JWT 模式（推荐）**
   - 通过 `issuePlatformAccessToken()` 签发 `typ=platform_plugin` 的 token
   - token 可携带：`userId`、`pluginId`、`scopes`
   - 请求时必须带：`X-Bricks-Plugin-Id`

Scope 控制：

- `events:read`
- `events:ack`
- `messages:write`
- `conversations:read`

### 3.3 协议路由层（`platform.ts`）

职责：做协议兼容、参数校验、错误码约束，再调用 service。

核心接口：

- `GET /api/v1/platform/events`
  - 拉取增量事件（cursor + limit）
- `POST /api/v1/platform/events/ack`
  - ACK 已消费事件
  - body 禁止传 `pluginId`
- `POST /api/v1/platform/messages`
  - 创建消息（兼容 `text/content` 与 `role/author` 字段）
- `PATCH /api/v1/platform/messages/:messageId`
  - 更新已有消息（文本或 metadata）
- `GET /api/v1/platform/conversations/resolve`
  - 根据 `conversationId` 或 `rawId` 解析会话归属

### 3.4 业务服务层（`platformIntegrationService.ts`）

职责：把“插件协议对象”映射到“聊天存储模型”。

- 事件读取：按 `write_seq` 从 `chat_messages` 增量读取
- ACK：MVP 阶段只做参数合法性校验（幂等），不做持久化
- 创建/更新消息：通过 `upsertMessages()` 写入 `chat_messages`
- 会话解析：支持 `session_id` 和 `channel/thread` 双向定位

---

## 4. 移动端辅助能力

### 4.1 Token 获取服务（`llm_config_service.dart`）

- `fetchPlatformToken()` 请求：`GET /api/config/platform-token`
- 返回解析为 `PlatformTokenBundle`：
  - `token`
  - `pluginId`
  - `baseUrl`
  - `scopes`
  - `expiresIn`

### 4.2 设置页使用（`model_settings_screen.dart`）

- 提供按钮：`Get Xiaolongxia Token`
- 展示 token 基础信息（Plugin ID / Base URL / Scopes）
- 支持一键复制 token 到剪贴板
- 错误场景给出 Snackbar 提示

---

## 5. 插件开发使用方法（Step-by-step）

## Step 1：准备环境变量（后端）

至少需要：

- `JWT_SECRET`（JWT 模式必需）
- `BRICKS_PLATFORM_API_KEY`（静态 Key 模式可选）
- `BRICKS_PLATFORM_API_SCOPES`（默认 scope 列表）
- `BRICKS_PLATFORM_DEFAULT_PLUGIN_ID`（默认插件 ID）
- `BRICKS_PLATFORM_BASE_URL`（返回给客户端的推荐访问地址）

## Step 2：获取插件 Token

### 方式 A：通过 App 设置页获取（推荐给人工调试）

1. 打开 Model Settings
2. 点击 `Get Xiaolongxia Token`
3. 复制生成的 token

### 方式 B：通过后端配置接口获取

`GET /api/config/platform-token?pluginId=plugin_local_main`

请求头：

```http
Authorization: Bearer <user_jwt>
```

返回示例：

```json
{
  "token": "<platform_jwt>",
  "pluginId": "plugin_local_main",
  "scopes": ["events:read", "events:ack", "messages:write", "conversations:read"],
  "baseUrl": "https://your-api-base",
  "expiresIn": "30d"
}
```

## Step 3：插件侧调用平台 API

所有请求必须携带：

```http
Authorization: Bearer <platform_jwt_or_static_key>
X-Bricks-Plugin-Id: plugin_local_main
```

### 3.1 拉取事件

```http
GET /api/v1/platform/events?cursor=cur_0&limit=50
```

### 3.2 ACK 事件

```http
POST /api/v1/platform/events/ack
Content-Type: application/json

{
  "cursor": "cur_12",
  "ackedEventIds": ["evt_msg_xxx_12"]
}
```

### 3.3 写入消息

```http
POST /api/v1/platform/messages
Content-Type: application/json

{
  "conversationId": "conv_001",
  "channelId": "ch_001",
  "threadId": "main",
  "text": "hello",
  "role": "assistant"
}
```

### 3.4 解析会话

```http
GET /api/v1/platform/conversations/resolve?conversationId=conv_001
```

---

## 6. 安全与约束建议

1. **优先使用 JWT 模式**，并把 token 作用域收敛到最小必要范围。  
2. **严格校验 `X-Bricks-Plugin-Id`**，避免跨插件复用 token。  
3. **不要在日志里落完整 token**，仅输出前后缀。  
4. **JWT 场景下 body 的 `userId` 不应覆盖 token 的 `userId`**（当前后端已做防护）。  
5. 生产环境定期轮换 `JWT_SECRET` 与静态 Key。  

---

## 7. 扩展点（给后续插件能力预留）

- ACK 持久化（用于精确投递语义）
- 插件配额与速率策略（按 pluginId / userId）
- 细粒度 scope（例如 `messages:patch` 与 `messages:create` 分离）
- 插件审计日志（安全与合规）
- 插件版本协商（v1/v2 协议演进）

---

## 8. 常见问题排查

- **401 UNAUTHORIZED**：检查 Bearer token 是否为空/过期/签名无效  
- **400 MISSING_PLUGIN_ID**：缺少 `X-Bricks-Plugin-Id` 请求头  
- **403 FORBIDDEN**：scope 不足或 token 的 pluginId 与请求头不一致  
- **INVALID_CURSOR**：游标格式不符合 `cur_<number>`

