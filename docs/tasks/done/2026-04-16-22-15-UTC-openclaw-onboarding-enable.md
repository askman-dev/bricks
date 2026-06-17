# Background
`apps/node_openclaw_plugin` 目前提供的是 pull-only 运行时示例，但尚未具备 OpenClaw 插件“安装后可在 onboarding/configure 向导中交互写入 channel 配置”的能力。用户希望 channel id 使用 `dev-askman-bricks`，并在配置过程中提示输入 `BRICKS_PLATFORM_TOKEN` 等必填参数，自动写入 `channels.dev-askman-bricks`。

# Goals
- 为 `apps/node_openclaw_plugin` 增加可被 OpenClaw 识别的插件元数据（manifest + package metadata）。
- 增加 channel onboarding hook（`configureInteractive`）以提示用户输入并返回配置。
- 在 README 中补充“子目录安装 + onboarding 配置”步骤，便于用户把说明交给 AI 自动执行。
- 同步代码地图索引，反映新增 onboarding 能力与风险点。

# Implementation Plan (phased)
## Phase 1: 插件清单与安装发现元数据
1. 新增 `openclaw.plugin.json`，声明 `channelConfigs.dev-askman-bricks` schema 与 `uiHints`。
2. 在 `package.json` 中补充 `openclaw.extensions/openclaw.channel/openclaw.install` 元数据，支持子目录与 npm 安装引导。

## Phase 2: onboarding 交互配置能力
1. 新增 OpenClaw 插件入口文件，导出带 `onboarding.configureInteractive(ctx)` 的插件对象。
2. 在 hook 中通过 `ctx.prompter.input` 询问 `BRICKS_BASE_URL`、`BRICKS_PLUGIN_ID`、`BRICKS_PLATFORM_TOKEN`。
3. 返回 `{ cfg, accountId }` 以让 OpenClaw 自动写入 `channels.dev-askman-bricks`。

## Phase 3: 文档、测试与代码地图
1. 更新 `apps/node_openclaw_plugin/README.md`，写清子目录安装、onboard/configure 流程、非 install lifecycle 限制。
2. 运行 TypeScript 构建与测试检查。
3. 更新 `docs/code_maps/feature_map.yaml` 与 `docs/code_maps/logic_map.yaml`。

# Acceptance Criteria
- `apps/node_openclaw_plugin` 包含可通过 OpenClaw 发现的 `openclaw.plugin.json` 与 `openclaw.extensions` 元数据。
- 安装插件后执行 onboarding/configure 时，向导可提示用户输入 token/base URL/plugin id，并将配置写入 `channels.dev-askman-bricks`。
- README 明确说明子目录安装步骤与配置命令。
- 代码地图已覆盖 onboarding 入口与回归风险。
