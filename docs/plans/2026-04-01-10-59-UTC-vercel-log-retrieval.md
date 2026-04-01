# Background
用户提供了一个 Vercel 日志页面链接（`/askman-dev/bricks/logs?...selectedLogId=...`），希望在容器环境中直接拿到对应日志内容。

# Goals
1. 尝试通过可用凭据和 API 访问该日志。
2. 若无法直接按 `selectedLogId` 精确提取，至少拿到同项目的最新可访问构建日志。
3. 记录可复现命令，便于后续继续排查。

# Implementation Plan (phased)
## Phase 1: 识别访问方式与鉴权
- 验证日志页面是否需要登录重定向。
- 检查环境变量是否存在 `VERCEL_TOKEN`。

## Phase 2: 通过 Vercel API 枚举团队/项目/部署
- 查询 team（slug: `askman-dev`）。
- 查询项目 `bricks` 的 `projectId`。
- 枚举最新部署并提取 deployment uid。

## Phase 3: 拉取部署构建日志并检索目标标识
- 调用 `GET /v3/deployments/{uid}/events` 获取构建日志流。
- 在最近部署事件中检索 `selectedLogId` 前缀（`qpksf`）。
- 若无命中，输出可访问日志样本与下一步建议（在 dashboard 中按时间定位 runtime log）。

# Acceptance Criteria
- 能确认页面是否登录受限（有明确 HTTP 重定向证据）。
- 能用 `VERCEL_TOKEN` 成功调用 Vercel API 并返回 `askman-dev/bricks` 项目信息。
- 能成功获取至少一个 deployment 的 build events 日志。
- 提供可复现命令（`curl`/`jq`）用于后续继续定位。
