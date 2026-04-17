# @bricks/node-openclaw-plugin

`@bricks/node-openclaw-plugin` 是一个 Node.js 的 Bricks/OpenClaw 集成插件，包含两部分能力：

1. **OpenClaw 插件安装 + onboarding 配置**（channel id: `dev-askman-bricks`）
2. **pull-only 运行时示例**（轮询 `events`、ACK、消息回写）

## 1) 作为 OpenClaw 插件安装（子目录安装）

> 本仓库场景下，插件在子目录 `apps/node_openclaw_plugin`。

```bash
openclaw plugins install ./apps/node_openclaw_plugin
openclaw gateway restart
```

也可使用链接安装（便于开发联调）：

```bash
openclaw plugins install -l ./apps/node_openclaw_plugin
openclaw gateway restart
```

## 2) onboarding / configure 自动写入 channel 配置

安装后运行：

```bash
openclaw onboard
# 或
openclaw configure
```

在向导中选择 `dev-askman-bricks`（Bricks）后，插件会提示输入：

- `BRICKS_BASE_URL`
- `BRICKS_PLUGIN_ID`
- `BRICKS_PLATFORM_TOKEN`

完成后会自动写入 `~/.openclaw/openclaw.json` 的：

```json
{
  "channels": {
    "dev-askman-bricks": {
      "BRICKS_BASE_URL": "https://your-bricks-api.example.com",
      "BRICKS_PLUGIN_ID": "dev-askman-bricks",
      "BRICKS_PLATFORM_TOKEN": "<JWT token>"
    }
  }
}
```

### 注意

`openclaw plugins install` 会使用 `npm install --ignore-scripts`，因此不要依赖 npm `postinstall` 写配置；应使用 onboarding hook 进行交互配置。

## 3) 本地 pull-only 运行时（独立示例）

该目录仍提供独立运行时示例，用于对接 Bricks 平台 API：

1. 轮询 `GET /api/v1/platform/events`
2. 本地按 `eventId` 去重
3. 调用 `POST /api/v1/platform/events/ack` 进行 ACK
4. 通过 `POST/PATCH /api/v1/platform/messages` 回写响应消息

### 环境变量

| 变量 | 必填 | 说明 |
|---|---|---|
| `BRICKS_BASE_URL` | 是 | Bricks API 基地址（例如 `http://localhost:8787`） |
| `BRICKS_PLATFORM_TOKEN` | 是 | 从 `/api/config/platform-token` 获取的 **JWT platform token**（仅支持 JWT） |
| `BRICKS_PLUGIN_ID` | 是 | 与请求头 `X-Bricks-Plugin-Id` 一致的插件标识 |
| `OPENCLAW_PLUGIN_POLL_INTERVAL_MS` | 否 | 轮询间隔，默认 `2000` |
| `OPENCLAW_PLUGIN_DEFAULT_CURSOR` | 否 | 初始游标，默认 `cur_0` |
| `OPENCLAW_PLUGIN_STATE_FILE` | 否 | 本地状态文件路径，默认 `~/.bricks/node_openclaw_plugin_state.json` |
| `OPENCLAW_PLUGIN_ASSISTANT_NAME` | 否 | 回写消息中的助手名，默认 `Node OpenClaw Plugin` |

### 本地运行

```bash
cd apps/node_openclaw_plugin
npm install
npm run dev
```

## 行为说明

- ACK body 仅包含 `cursor` 与 `ackedEventIds`，不发送 `pluginId` 字段。
- 启动阶段会校验 JWT claims：`typ=platform_plugin`、`pluginId` 与 `BRICKS_PLUGIN_ID` 一致、且必须包含 `userId`。
- 收到 `message.created` 时会先写入一条 streaming 消息，随后通过 PATCH 更新消息的 `text`/`metadata`；当前不会将 `status` patch 为 `completed`。
- 收到 `conversation.binding_changed` 时当前仅记录日志（MVP noop）。
