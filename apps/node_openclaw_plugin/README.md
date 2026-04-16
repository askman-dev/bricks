# node_openclaw_plugin

`node_openclaw_plugin` 是一个基于 Node.js 的 OpenClaw pull-only 插件运行时实现，用于对接 Bricks 平台 API：

1. 轮询 `GET /api/v1/platform/events`
2. 本地按 `eventId` 去重
3. 调用 `POST /api/v1/platform/events/ack` 进行 ACK
4. 通过 `POST/PATCH /api/v1/platform/messages` 回写响应消息

## 环境变量

| 变量 | 必填 | 说明 |
|---|---|---|
| `BRICKS_BASE_URL` | 是 | Bricks API 基地址（例如 `http://localhost:8787`） |
| `BRICKS_PLATFORM_TOKEN` | 是 | 从 `/api/config/platform-token` 获取的 **JWT platform token**（仅支持 JWT） |
| `BRICKS_PLUGIN_ID` | 是 | 与请求头 `X-Bricks-Plugin-Id` 一致的插件标识 |
| `OPENCLAW_PLUGIN_POLL_INTERVAL_MS` | 否 | 轮询间隔，默认 `2000` |
| `OPENCLAW_PLUGIN_DEFAULT_CURSOR` | 否 | 初始游标，默认 `cur_0` |
| `OPENCLAW_PLUGIN_STATE_FILE` | 否 | 本地状态文件路径，默认 `~/.bricks/node_openclaw_plugin_state.json` |
| `OPENCLAW_PLUGIN_ASSISTANT_NAME` | 否 | 回写消息中的助手名，默认 `Node OpenClaw Plugin` |

## 本地运行

```bash
cd apps/node_openclaw_plugin
npm install
npm run dev
```

## 说明

- ACK body 仅包含 `cursor` 与 `ackedEventIds`，不发送 `pluginId` 字段。
- 启动阶段会校验 JWT claims：`typ=platform_plugin`、`pluginId` 与 `BRICKS_PLUGIN_ID` 一致、且必须包含 `userId`。
- 收到 `message.created` 时会写入一条 streaming 消息并 patch 为 completed。
- 收到 `conversation.binding_changed` 时当前仅记录日志（MVP noop）。
