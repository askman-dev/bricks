# Background
用户反馈上一版 `node_openclaw_plugin` 与目标不一致：需要明确该实现是用于 OpenClaw 对接的插件运行时（而非文档描述中的宽泛 adapter 表述），并且需要在代码层面真正收敛到 JWT token 路径，避免“文档改了但逻辑仍保留静态 key 兼容”的遗留错误资产。

# Goals
- 将 `node_openclaw_plugin` 的运行前校验与调用语义收敛为 JWT-only。
- 修复当前插件与后端平台接口字段不一致导致的消息 patch 失效问题。
- 修复 ACK 与本地状态持久化顺序问题，避免 ACK 成功但本地状态未落盘。
- 同步更新 README 与架构文档，消除“adapter/bridge”歧义与静态 key 残留描述。

# Implementation Plan (phased)
## Phase 1: JWT-only 运行时约束
1. 新增 JWT claims 解析与基础校验逻辑（typ/pluginId/userId/exp）。
2. 在启动配置加载阶段强制校验 token，失败直接退出。
3. 在运行时使用 token userId 执行消息过滤（避免自触发回环）。

## Phase 2: 协议对齐与可靠性修复
1. 将消息 patch 字段调整为后端当前可识别的 `text`/`metadata`。
2. 重构 ACK 流程：先持久化 pending ACK，再发送 ACK，成功后提交 cursor。
3. 为 pending ACK 增加重试入口，确保崩溃恢复后可继续推进 cursor。

## Phase 3: 文档与测试收口
1. 更新 `apps/node_openclaw_plugin/README.md`：明确 OpenClaw 插件运行时 + JWT-only。
2. 更新 `docs/plugin_development_architecture.md` 代码结构，纳入新插件目录。
3. 增加测试覆盖 JWT claims 校验与状态仓库新字段兼容。

# Acceptance Criteria
- 插件启动时若 token 非合法 JWT claims（缺 typ/pluginId/userId 或过期）会直接失败。
- 插件向 `PATCH /api/v1/platform/messages/:id` 发送后端可识别字段并能更新文本。
- ACK 流程具备 pending 持久化，崩溃恢复后可继续 ACK 并推进 cursor。
- README 不再声明静态 key 支持，且语义明确为 OpenClaw 插件运行时。
