# @bricks/node-openclaw-plugin

`@bricks/node-openclaw-plugin` 是一个 Node.js 的 Bricks/OpenClaw 集成插件，包含两部分能力：

1. **OpenClaw 插件安装 + onboarding 配置**（channel id: `dev-askman-bricks`）
2. **pull-only 运行时**（轮询 `events`、ACK、OpenClaw handoff、消息回写）

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

## 2) 作为真实 channel plugin 写入 `channels.dev-askman-bricks`

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

如果只想改 Bricks 这一项，不想重新跑整套 onboarding，也可以直接写 channel 配置：

```bash
openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL https://your-bricks-api.example.com
openclaw config set channels.dev-askman-bricks.BRICKS_PLUGIN_ID dev-askman-bricks
openclaw config set channels.dev-askman-bricks.BRICKS_PLATFORM_TOKEN 'your-jwt-token'
openclaw config validate
openclaw gateway restart
```

### 注意

`openclaw plugins install` 会使用 `npm install --ignore-scripts`，因此不要依赖 npm `postinstall` 写配置；应使用 channel setup/onboarding 或 `openclaw config set channels.dev-askman-bricks.*` 完成配置。

## 3) OpenClaw 托管运行时（默认）

安装并配置完成后，Bricks pull runner 会由 OpenClaw gateway 通过 channel
`gateway.startAccount/stopAccount` 生命周期自动托管：

1. `openclaw gateway restart` / gateway 启动时自动拉起 Bricks runner
2. runner 轮询 `GET /api/v1/platform/events`
3. 调用 `POST /api/v1/platform/events/ack` 进行 ACK
4. 将 Bricks 用户消息转交给 OpenClaw 内部 session/reply pipeline
5. 通过 `POST/PATCH /api/v1/platform/messages` 回写 OpenClaw 的可见输出
6. gateway 停止或重启时，通过 `AbortSignal` 优雅停止 runner

### OpenClaw 控制

推荐测试方式：

```bash
openclaw gateway restart
```

不再需要为了真实回复而手工 `npm start` 这个插件；只要 OpenClaw gateway 正常运行，Bricks runner 会由 OpenClaw 宿主自动管理。

### 可选环境变量

| 变量 | 必填 | 说明 |
|---|---|---|
| `OPENCLAW_PLUGIN_POLL_INTERVAL_MS` | 否 | 轮询间隔，默认 `2000` |
| `OPENCLAW_PLUGIN_DEFAULT_CURSOR` | 否 | 初始游标，默认 `cur_0` |
| `OPENCLAW_PLUGIN_STATE_FILE` | 否 | 本地状态文件路径，默认 `~/.bricks/node_openclaw_plugin_state.json` |
| `OPENCLAW_PLUGIN_ASSISTANT_NAME` | 否 | 回写消息中的助手名，默认 `Node OpenClaw Plugin` |

Bricks 连接参数 (`BRICKS_BASE_URL`、`BRICKS_PLUGIN_ID`、`BRICKS_PLATFORM_TOKEN`) 在 OpenClaw 托管模式下优先从 `channels.dev-askman-bricks` 的已配置 channel account 读取，而不是要求手工导出 shell 环境变量。

## 4) 本地独立调试（仅开发用）

如果只是脱离 OpenClaw gateway 单独调试 runner，仍可手工运行：

```bash
cd apps/node_openclaw_plugin
npm install
npm start
```

## 行为说明

- ACK body 仅包含 `cursor` 与 `ackedEventIds`，不发送 `pluginId` 字段。
- 启动阶段会校验 JWT claims：`typ=platform_plugin`、`pluginId` 与 `BRICKS_PLUGIN_ID` 一致、且必须包含 `userId`。
- OpenClaw channel account scoping uses the stored platform token's `userId` claim. If `BRICKS_PLUGIN_ID` / `BRICKS_PLATFORM_TOKEN` are missing or invalid, OpenClaw status/config flows now fail loudly so the user fixes the stored config instead of silently falling back to `default`.
- 收到 `message.created` 时会先写入一条 streaming 消息，再把用户输入交给 OpenClaw 的真实 inbound/session pipeline；OpenClaw 的可见输出会逐段累积并 PATCH 回同一条 assistant 消息。
- OpenClaw session key 按 Bricks `channelId` / `threadId` 作用域稳定映射：channel 走基础 session，thread 走 `:thread:<threadId>` 后缀，这样 OpenClaw 本地 transcript 会按 Bricks 会话边界保留 history。
- 回写时当前仍聚合到同一条 assistant message；OpenClaw 返回的媒体暂时会退化为可见 URL 文本，便于先把真实 handoff 跑通。
- 当前真实回复路径由 OpenClaw gateway 托管：gateway restart 时会停止旧 runner 并重新拉起新 runner，runner 复用同一个本地 state/cursor 文件继续轮询。
- 收到 `conversation.binding_changed` 时当前仅记录日志（MVP noop）。
