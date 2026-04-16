# Background
用户希望“根据文档实现 node_openclaw_plugin”。仓库当前已具备 Bricks 平台侧 pull-only API（`/api/v1/platform/*`）与 token 签发能力，但尚无独立的 Node.js 插件示例/运行时来执行文档中的事件拉取、ACK、消息写回闭环。

# Goals
- 新增 `apps/node_openclaw_plugin`，提供最小可运行的 Node.js/TypeScript 插件实现。
- 按文档实现 pull-only 主循环：拉取事件、去重处理、ACK、消息回写。
- 提供环境变量与运行说明，便于本地联调。
- 增加基础单测，覆盖关键状态持久化与处理逻辑。
- 同步更新代码地图索引，确保新功能可被测试与 AI 检索。

# Implementation Plan (phased)
## Phase 1: 项目骨架与客户端
1. 创建 `apps/node_openclaw_plugin` 包（`package.json`、`tsconfig.json`、`src/`）。
2. 实现平台 API 客户端：`events` 拉取、`events/ack`、`messages` 创建/更新、`conversations/resolve`。
3. 定义插件内部类型与错误处理（标准化 HTTP 异常）。

## Phase 2: 事件处理与状态持久化
1. 实现文件状态仓库（`cursor`、`processedEventIds`、`clientToken->messageId` 映射）。
2. 实现插件运行器：轮询、按 `eventId` 去重、按批 ACK、失败重试边界。
3. 为 `message.created` 事件实现示例回写逻辑（create + patch）。
4. 为 `conversation.binding_changed` 增加日志处理分支（MVP noop）。

## Phase 3: 文档、测试与代码地图
1. 添加插件目录 README（环境变量、运行命令、行为说明）。
2. 编写并运行单测（状态仓库/处理流程）。
3. 更新 `docs/code_maps/feature_map.yaml` 与 `docs/code_maps/logic_map.yaml`，纳入新插件功能索引。

# Acceptance Criteria
- 在 `apps/node_openclaw_plugin` 下可执行 `npm run build`、`npm run test` 并通过。
- 插件主循环可根据环境变量连接 Bricks API，执行“pull -> process -> ack -> writeback”流程。
- ACK 请求体不包含 `pluginId`，并使用请求头 `X-Bricks-Plugin-Id`。
- 本地状态可持久化并在重启后继续使用 cursor 与去重集合。
- 代码地图已更新，包含 `node_openclaw_plugin` 的入口、代码索引与回归风险。
